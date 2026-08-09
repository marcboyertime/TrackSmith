import Combine
import Foundation
import SwiftUI
import VocalProduction

enum VocalCaptureBriefEditorError: Error, CustomStringConvertible {
    case missingDesiredResult
    case missingPriority
    case missingPreservation
    case knownEquipmentMissingIdentity(String)
    case invalidMaximumSetupTime

    var description: String {
        switch self {
        case .missingDesiredResult:
            "Describe the capture result you want before loading the brief."
        case .missingPriority:
            "Select at least one capture priority."
        case .missingPreservation:
            "Select at least one performance or voice attribute to preserve."
        case let .knownEquipmentMissingIdentity(label):
            "\(label) is marked known, but no maker or model was entered."
        case .invalidMaximumSetupTime:
            "Maximum setup time must be a positive finite number of minutes."
        }
    }
}

/// Musician-entered capture facts. Every hardware field starts unknown; this
/// model never guesses a device, pickup pattern, room, or noise source.
@MainActor
final class VocalCaptureBriefEditorModel: ObservableObject {
    @Published var desiredResult = ""

    @Published var microphoneState: VocalKnowledgeState = .unknown
    @Published var microphoneManufacturer = ""
    @Published var microphoneModel = ""
    @Published var interfaceState: VocalKnowledgeState = .unknown
    @Published var interfaceManufacturer = ""
    @Published var interfaceModel = ""
    @Published var preampState: VocalKnowledgeState = .unknown
    @Published var preampManufacturer = ""
    @Published var preampModel = ""
    @Published var headphonesState: VocalKnowledgeState = .unknown
    @Published var headphonesManufacturer = ""
    @Published var headphonesModel = ""
    @Published var popFilterState: VocalKnowledgeState = .unknown
    @Published var popFilterManufacturer = ""
    @Published var popFilterModel = ""

    @Published var microphonePatternState: VocalKnowledgeState = .unknown
    @Published var microphonePattern: VocalMicPattern = .cardioid

    @Published var roomDescription = ""
    @Published var roomSizeKnown = false
    @Published var backgroundNoise: VocalConditionLevel = .unknown
    @Published var reflectionRisk: VocalConditionLevel = .unknown
    @Published var movableSoftMaterials: VocalKnowledgeState = .unknown
    @Published var knownNoiseSources = ""
    @Published var roomObservations = ""

    @Published var maximumSetupMinutes = ""
    @Published var fixedRoomPosition = false
    @Published var fixedMicrophone = false
    @Published var noAdditionalEquipment = false
    @Published var performerComfortIsHardConstraint = true
    @Published var otherConstraint = ""

    @Published var priorityWeights: [VocalCapturePriority: Double] = [:]
    @Published var preservePerformanceAttributes: Set<VocalPerformanceAttribute> = []
    @Published var preserveVoiceAspects: Set<VocalAspect> = [
        .voiceIdentity,
        .pitch,
        .timing,
        .dynamics,
    ]
    @Published var assumptions = ""
    @Published var uncertainty = ""
    @Published var validationMessage: String?

    private let briefID = UUID()

    func buildBrief() throws -> VocalCaptureBrief {
        let desired = desiredResult.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desired.isEmpty else { throw VocalCaptureBriefEditorError.missingDesiredResult }
        guard !priorityWeights.isEmpty else { throw VocalCaptureBriefEditorError.missingPriority }
        guard !preservePerformanceAttributes.isEmpty || !preserveVoiceAspects.isEmpty else {
            throw VocalCaptureBriefEditorError.missingPreservation
        }

        let microphone = try equipment(
            label: "Microphone",
            kind: .microphone,
            state: microphoneState,
            manufacturer: microphoneManufacturer,
            model: microphoneModel
        )
        let audioInterface = try equipment(
            label: "Audio interface",
            kind: .audioInterface,
            state: interfaceState,
            manufacturer: interfaceManufacturer,
            model: interfaceModel
        )
        let preamp = try equipment(
            label: "External preamp",
            kind: .externalPreamp,
            state: preampState,
            manufacturer: preampManufacturer,
            model: preampModel
        )
        let headphones = try equipment(
            label: "Headphones",
            kind: .headphones,
            state: headphonesState,
            manufacturer: headphonesManufacturer,
            model: headphonesModel
        )
        let popFilter = try equipment(
            label: "Pop filter",
            kind: .popFilter,
            state: popFilterState,
            manufacturer: popFilterManufacturer,
            model: popFilterModel,
            knownIdentityRequired: false
        )

        let equipment = VocalCaptureEquipment(
            microphone: microphone,
            audioInterface: audioInterface,
            externalPreamp: preamp,
            headphones: headphones,
            popFilter: popFilter
        )
        let environment = VocalCaptureEnvironment(
            backgroundNoise: backgroundNoise,
            reflectionRisk: reflectionRisk,
            roomSizeKnown: roomSizeKnown,
            roomDescription: optional(roomDescription),
            movableSoftMaterialsAvailable: movableSoftMaterials,
            knownNoiseSources: lines(knownNoiseSources),
            observations: lines(roomObservations),
            provenance: [userReportedProvenance("capture-room-and-noise-input")]
        )
        let priorities = priorityWeights
            .map { VocalCapturePriorityWeight(priority: $0.key, weight: $0.value) }
            .sorted {
                if $0.weight == $1.weight { return $0.priority.rawValue < $1.priority.rawValue }
                return $0.weight > $1.weight
            }
        let constraints = try buildConstraints()
        let missing = missingInformation()
        let uncertaintyLines = lines(uncertainty) + (missing.isEmpty ? [] : [
            "Unknown or unsure fields remain explicit; proposals must not infer device-specific behavior.",
        ])

        return VocalCaptureBrief(
            id: briefID,
            desiredResult: desired,
            priorities: priorities,
            equipment: equipment,
            microphonePattern: VocalMicPatternKnowledge(
                state: microphonePatternState,
                pattern: microphonePatternState == .known ? microphonePattern : nil,
                confirmedByUser: microphonePatternState == .known
            ),
            environment: environment,
            practicalConstraints: constraints,
            preservePerformanceAttributes: preservePerformanceAttributes.sorted {
                $0.rawValue < $1.rawValue
            },
            preserveVoiceAttributes: preserveVoiceAspects.sorted { $0.rawValue < $1.rawValue },
            assumptions: lines(assumptions),
            missingInformation: missing,
            uncertainty: uncertaintyLines,
            provenance: [userReportedProvenance("capture-brief-musician-input")]
        )
    }

    func submit(_ load: (VocalCaptureBrief) -> Void) {
        do {
            let brief = try buildBrief()
            validationMessage = nil
            load(brief)
        } catch {
            validationMessage = String(describing: error)
        }
    }

    private func equipment(
        label: String,
        kind: VocalEquipmentKind,
        state: VocalKnowledgeState,
        manufacturer: String,
        model: String,
        knownIdentityRequired: Bool = true
    ) throws -> VocalEquipmentItem {
        let maker = state == .known ? optional(manufacturer) : nil
        let exactModel = state == .known ? optional(model) : nil
        if state == .known, knownIdentityRequired, maker == nil, exactModel == nil {
            throw VocalCaptureBriefEditorError.knownEquipmentMissingIdentity(label)
        }
        let uncertainty: [String]
        switch state {
        case .known, .notPresent:
            uncertainty = []
        case .unknown:
            uncertainty = ["The musician marked the \(label.lowercased()) as unknown."]
        case .userUnsure:
            uncertainty = ["The musician is unsure about the \(label.lowercased())."]
        }
        return VocalEquipmentItem(
            kind: kind,
            state: state,
            manufacturer: maker,
            model: exactModel,
            uncertainty: uncertainty
        )
    }

    private func buildConstraints() throws -> [VocalCaptureConstraint] {
        var result: [VocalCaptureConstraint] = []
        if let minutes = optional(maximumSetupMinutes) {
            guard let value = Double(minutes), value.isFinite, value > 0 else {
                throw VocalCaptureBriefEditorError.invalidMaximumSetupTime
            }
            result.append(VocalCaptureConstraint(
                kind: .maximumSetupTime,
                description: "Maximum setup time entered by musician: \(value.formatted()) minutes.",
                hardConstraint: true
            ))
        }
        if fixedRoomPosition {
            result.append(VocalCaptureConstraint(
                kind: .fixedRoomPosition,
                description: "Keep the current room position.",
                hardConstraint: true
            ))
        }
        if fixedMicrophone {
            result.append(VocalCaptureConstraint(
                kind: .fixedMicrophone,
                description: "Use the current microphone.",
                hardConstraint: true
            ))
        }
        if noAdditionalEquipment {
            result.append(VocalCaptureConstraint(
                kind: .noAdditionalEquipment,
                description: "Do not add equipment.",
                hardConstraint: true
            ))
        }
        if performerComfortIsHardConstraint {
            result.append(VocalCaptureConstraint(
                kind: .performerComfort,
                description: "Stop or roll back if performer comfort worsens.",
                hardConstraint: true
            ))
        }
        if let other = optional(otherConstraint) {
            result.append(VocalCaptureConstraint(
                kind: .other,
                description: other,
                hardConstraint: true
            ))
        }
        return result
    }

    private func missingInformation() -> [String] {
        let fields: [(String, VocalKnowledgeState)] = [
            ("microphone", microphoneState),
            ("audio interface", interfaceState),
            ("external preamp", preampState),
            ("headphones", headphonesState),
            ("pop filter", popFilterState),
            ("microphone pickup pattern", microphonePatternState),
            ("movable soft materials", movableSoftMaterials),
        ]
        return fields.compactMap { label, state in
            switch state {
            case .unknown: "Unknown \(label)."
            case .userUnsure: "Musician is unsure about \(label)."
            case .known, .notPresent: nil
            }
        }
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func lines(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func userReportedProvenance(_ identifier: String) -> VocalProvenance {
        VocalProvenance(
            identifier: identifier,
            evidenceKind: .userReported,
            statement: "Musician-entered capture information; no hardware or acoustic behavior was inferred.",
            limitations: ["Unverified user entry remains distinct from measurements and listening evidence."],
            confidence: 1
        )
    }
}

struct VocalCaptureBriefEditorView: View {
    @ObservedObject var editor: VocalCaptureBriefEditorModel
    let loadBrief: (VocalCaptureBrief) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                    Text("Enter the capture brief")
                        .font(Theme.Font.body.weight(.medium))
                    Text("Use what you actually know. Unknown is a valid answer and prevents device-specific guesses.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                Spacer()
                VocalTag(text: "MUSICIAN INPUT", accent: true)
            }

            field("Desired result") {
                multilineField(
                    "Example: intimate and clear, with natural dynamics and no distracting room sound",
                    text: $editor.desiredResult
                )
            }

            DisclosureGroup("Equipment facts") {
                VStack(spacing: Theme.Spacing.eight) {
                    equipmentRow(
                        "Microphone",
                        state: $editor.microphoneState,
                        manufacturer: $editor.microphoneManufacturer,
                        model: $editor.microphoneModel,
                        allowsNotPresent: false
                    )
                    equipmentRow(
                        "Audio interface",
                        state: $editor.interfaceState,
                        manufacturer: $editor.interfaceManufacturer,
                        model: $editor.interfaceModel,
                        allowsNotPresent: false
                    )
                    equipmentRow(
                        "External preamp",
                        state: $editor.preampState,
                        manufacturer: $editor.preampManufacturer,
                        model: $editor.preampModel,
                        allowsNotPresent: true
                    )
                    equipmentRow(
                        "Headphones",
                        state: $editor.headphonesState,
                        manufacturer: $editor.headphonesManufacturer,
                        model: $editor.headphonesModel,
                        allowsNotPresent: false
                    )
                    equipmentRow(
                        "Pop filter",
                        state: $editor.popFilterState,
                        manufacturer: $editor.popFilterManufacturer,
                        model: $editor.popFilterModel,
                        allowsNotPresent: true
                    )

                    HStack(spacing: Theme.Spacing.eight) {
                        Text("Mic pattern")
                            .font(Theme.Font.meta)
                            .frame(width: 118, alignment: .leading)
                        knowledgePicker(selection: $editor.microphonePatternState, allowsNotPresent: false)
                        if editor.microphonePatternState == .known {
                            Picker("Pattern", selection: $editor.microphonePattern) {
                                ForEach(VocalMicPattern.allCases, id: \.self) { pattern in
                                    Text(words(pattern.rawValue)).tag(pattern)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            DisclosureGroup("Room, noise, and practical constraints") {
                VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                    multilineField("Room description (optional)", text: $editor.roomDescription)
                    HStack(spacing: Theme.Spacing.eight) {
                        conditionPicker("Background noise", selection: $editor.backgroundNoise)
                        conditionPicker("Reflection risk", selection: $editor.reflectionRisk)
                        knowledgeField("Movable soft materials", selection: $editor.movableSoftMaterials)
                    }
                    Toggle("I know the room size", isOn: $editor.roomSizeKnown)
                    multilineField("Known noise sources, separated by commas or lines", text: $editor.knownNoiseSources)
                    multilineField("Room observations, separated by commas or lines", text: $editor.roomObservations)
                    HStack(spacing: Theme.Spacing.eight) {
                        compactField("Maximum setup minutes", text: $editor.maximumSetupMinutes)
                        Toggle("Fixed room position", isOn: $editor.fixedRoomPosition)
                        Toggle("Fixed microphone", isOn: $editor.fixedMicrophone)
                    }
                    HStack(spacing: Theme.Spacing.eight) {
                        Toggle("No additional equipment", isOn: $editor.noAdditionalEquipment)
                        Toggle("Performer comfort is a stop condition", isOn: $editor.performerComfortIsHardConstraint)
                    }
                    multilineField("Other hard constraint (optional)", text: $editor.otherConstraint)
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            DisclosureGroup("Priorities and preservation") {
                VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
                    Text("Capture priorities")
                        .font(Theme.Font.section)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 210), spacing: Theme.Spacing.eight)],
                        spacing: Theme.Spacing.eight
                    ) {
                        ForEach(VocalCapturePriority.allCases, id: \.self) { priority in
                            priorityControl(priority)
                        }
                    }

                    Text("Preserve performance")
                        .font(Theme.Font.section)
                    selectionGrid(VocalPerformanceAttribute.allCases, selection: $editor.preservePerformanceAttributes)

                    Text("Preserve voice / musical identity")
                        .font(Theme.Font.section)
                    selectionGrid(VocalAspect.allCases, selection: $editor.preserveVoiceAspects)
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            DisclosureGroup("Assumptions and uncertainty") {
                VStack(spacing: Theme.Spacing.eight) {
                    multilineField("Only assumptions you want carried forward", text: $editor.assumptions)
                    multilineField("Anything you are unsure about", text: $editor.uncertainty)
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            if let validation = editor.validationMessage {
                Label(validation, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Font.meta)
                    .foregroundStyle(.orange)
            }

            HStack {
                VocalHonestyNote(
                    text: "Loading this brief records typed intent only. It does not analyze audio, choose a setup, or operate Logic."
                )
                Button("Load typed capture brief") {
                    editor.submit(loadBrief)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func equipmentRow(
        _ label: String,
        state: Binding<VocalKnowledgeState>,
        manufacturer: Binding<String>,
        model: Binding<String>,
        allowsNotPresent: Bool
    ) -> some View {
        HStack(spacing: Theme.Spacing.eight) {
            Text(label)
                .font(Theme.Font.meta)
                .frame(width: 118, alignment: .leading)
            knowledgePicker(selection: state, allowsNotPresent: allowsNotPresent)
            if state.wrappedValue == .known {
                compactField("Maker", text: manufacturer)
                compactField("Model", text: model)
            } else {
                Text("No device identity assumed")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
                Spacer()
            }
        }
    }

    private func knowledgePicker(
        selection: Binding<VocalKnowledgeState>,
        allowsNotPresent: Bool
    ) -> some View {
        let states: [VocalKnowledgeState] = allowsNotPresent
            ? [.known, .unknown, .userUnsure, .notPresent]
            : [.known, .unknown, .userUnsure]
        return Picker("Knowledge", selection: selection) {
            ForEach(states, id: \.self) { state in
                Text(words(state.rawValue)).tag(state)
            }
        }
        .labelsHidden()
        .frame(width: 130)
    }

    private func conditionPicker(
        _ label: String,
        selection: Binding<VocalConditionLevel>
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
            Text(label).font(Theme.Font.meta)
            Picker(label, selection: selection) {
                ForEach(VocalConditionLevel.allCases, id: \.self) { level in
                    Text(words(level.rawValue)).tag(level)
                }
            }
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func knowledgeField(
        _ label: String,
        selection: Binding<VocalKnowledgeState>
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
            Text(label).font(Theme.Font.meta)
            knowledgePicker(selection: selection, allowsNotPresent: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priorityControl(_ priority: VocalCapturePriority) -> some View {
        let enabled = editor.priorityWeights[priority] != nil
        let binding = Binding(
            get: { editor.priorityWeights[priority] ?? 0.75 },
            set: { editor.priorityWeights[priority] = $0 }
        )
        return VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Toggle(
                words(priority.rawValue),
                isOn: Binding(
                    get: { enabled },
                    set: { selected in
                        if selected { editor.priorityWeights[priority] = 0.75 }
                        else { editor.priorityWeights.removeValue(forKey: priority) }
                    }
                )
            )
            if enabled {
                HStack {
                    Slider(value: binding, in: 0...1, step: 0.05)
                    Text("\(Int((binding.wrappedValue * 100).rounded()))%")
                        .font(Theme.Font.data)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(Theme.Spacing.eight)
        .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func selectionGrid<Value: Hashable & RawRepresentable>(
        _ values: [Value],
        selection: Binding<Set<Value>>
    ) -> some View where Value.RawValue == String {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.eight)],
            spacing: Theme.Spacing.eight
        ) {
            ForEach(values, id: \.self) { value in
                Toggle(
                    words(value.rawValue),
                    isOn: Binding(
                        get: { selection.wrappedValue.contains(value) },
                        set: { selected in
                            if selected { selection.wrappedValue.insert(value) }
                            else { selection.wrappedValue.remove(value) }
                        }
                    )
                )
                .padding(.horizontal, Theme.Spacing.eight)
                .padding(.vertical, Theme.Spacing.four)
                .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }
        }
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(label).font(Theme.Font.section)
            content()
        }
    }

    private func multilineField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...4)
            .padding(Theme.Spacing.eight)
            .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
    }

    private func compactField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(Theme.Spacing.eight)
            .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
    }

    private func words(_ value: String) -> String {
        VocalWorkspacePresentation.words(value)
    }
}
