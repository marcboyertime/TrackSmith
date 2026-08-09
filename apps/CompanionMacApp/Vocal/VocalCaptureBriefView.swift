import SwiftUI
import VocalProduction

struct VocalCaptureBriefView: View {
    @ObservedObject var model: VocalWorkspaceModel
    let callbacks: VocalWorkspaceCallbacks

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            VocalSectionHeader(
                index: "1",
                title: "Capture brief",
                detail: "Known facts, unknown hardware, priorities, constraints, and what the performance must preserve."
            )

            if let brief = model.captureBrief {
                VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                            Text(brief.desiredResult)
                                .font(Theme.Font.body)
                            Text("Brief \(VocalWorkspacePresentation.shortID(brief.id))")
                                .font(Theme.Font.data)
                                .foregroundStyle(Theme.Colors.mutedText)
                        }
                        Spacer()
                        Button("Request 3 capture plans") {
                            callbacks.requestCaptureInterpretations(brief)
                            model.noteRequest(
                                "Three capture interpretations requested; no plan has been accepted or tested."
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.accent)
                    }

                    Divider().overlay(Theme.Colors.hairline)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.eight)],
                        alignment: .leading,
                        spacing: Theme.Spacing.eight
                    ) {
                        hardwareRow("Microphone", item: brief.equipment.microphone)
                        hardwareRow("Interface", item: brief.equipment.audioInterface)
                        hardwareRow("External preamp", item: brief.equipment.externalPreamp)
                        hardwareRow("Headphones", item: brief.equipment.headphones)
                        hardwareRow("Pop filter", item: brief.equipment.popFilter)
                        VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                            Text("Pickup pattern")
                                .font(Theme.Font.meta)
                                .foregroundStyle(Theme.Colors.mutedText)
                            Text(patternLabel(brief.microphonePattern))
                                .font(Theme.Font.section)
                        }
                    }

                    HStack(alignment: .top, spacing: Theme.Spacing.twelve) {
                        labeledList(
                            "Priorities",
                            brief.priorities.sorted { $0.weight > $1.weight }.map {
                                "\(VocalWorkspacePresentation.words($0.priority.rawValue)) · \(VocalWorkspacePresentation.percentage($0.weight))"
                            }
                        )
                        labeledList(
                            "Preserve",
                            brief.preservePerformanceAttributes.map {
                                VocalWorkspacePresentation.words($0.rawValue)
                            } + brief.preserveVoiceAttributes.map {
                                VocalWorkspacePresentation.words($0.rawValue)
                            }
                        )
                        labeledList(
                            "Constraints / unknowns",
                            brief.practicalConstraints.map(\.description)
                                + brief.missingInformation
                                + brief.uncertainty
                        )
                    }

                    if brief.equipment.containsUnknownHardware
                        || brief.microphonePattern.state != .known {
                        VocalHonestyNote(
                            text: "Hardware behavior is not inferred. Capture proposals must remain relative, bounded, reversible listening experiments."
                        )
                    }
                }
                .padding(Theme.Spacing.twelve)
                .instrumentSurface(.raised, radius: Theme.Radius.medium)
            } else {
                VocalHonestyNote(
                    text: "No typed VocalCaptureBrief has been supplied. The parent must build it from confirmed information before capture plans can be requested."
                )
            }
        }
    }

    private func hardwareRow(_ label: String, item: VocalEquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
            Text(label)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Colors.mutedText)
            Text(equipmentLabel(item))
                .font(Theme.Font.section)
            if !item.uncertainty.isEmpty {
                Text(item.uncertainty.joined(separator: " · "))
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private func equipmentLabel(_ item: VocalEquipmentItem) -> String {
        guard item.state == .known else {
            return VocalWorkspacePresentation.words(item.state.rawValue)
        }
        let identity = [item.manufacturer, item.model]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return identity.isEmpty ? "Known · identity not entered" : identity
    }

    private func patternLabel(_ knowledge: VocalMicPatternKnowledge) -> String {
        guard knowledge.state == .known, let pattern = knowledge.pattern else {
            return VocalWorkspacePresentation.words(knowledge.state.rawValue)
        }
        return "\(VocalWorkspacePresentation.words(pattern.rawValue)) · \(knowledge.confirmedByUser ? "user confirmed" : "not user confirmed")"
    }

    private func labeledList(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(title).font(Theme.Font.section)
            if items.isEmpty {
                Text("None recorded")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            } else {
                VocalBulletList(items: items, limit: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
