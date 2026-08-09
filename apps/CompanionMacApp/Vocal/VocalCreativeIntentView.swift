import SwiftUI
import VocalProduction

struct VocalCreativeIntentView: View {
    @ObservedObject var model: VocalWorkspaceModel
    let callbacks: VocalWorkspaceCallbacks

    private let requiredPrompts = [
        "Make the vocal feel underwater while preserving pitch, melody, timing, and intelligibility.",
        "Give the vocal trumpet/brass-like color while preserving the singer, melody, and timing.",
    ]

    private let metaphorPrompts = [
        "Make it glassy but not sharp",
        "Make it smoky and close",
        "Make it enormous but distant",
        "Make it fragile without changing pitch",
        "Make it broken but intelligible",
        "Make it feel like it is floating",
        "Give it a metallic edge",
        "Make it radio-like but preserve consonants",
        "Make it dreamlike with slow movement",
        "Make it unstable without retiming it",
        "Make it extremely intimate",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            VocalSectionHeader(
                index: "5",
                title: "Typed creative intent",
                detail: "Translate musician language into scope, preservation, ambiguity, editability, and an honest processing boundary."
            )

            promptComposer

            if let intent = model.creativeIntent {
                intentInspection(intent)
            } else {
                VocalHonestyNote(
                    text: "No typed VocalCreativeIntent has been supplied. Prompt text alone has no DSP authority and cannot select arbitrary processing."
                )
            }
        }
    }

    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            HStack {
                Text("Describe the sound")
                    .font(Theme.Font.section)
                Spacer()
                Text("Request only · ⌘↩")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }

            TextField(
                "Describe the vocal transformation and what must stay intact",
                text: $model.creativePrompt,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(2...5)
            .padding(Theme.Spacing.twelve)
            .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                Text("Required v1 requests")
                    .font(Theme.Font.meta.weight(.semibold))
                ForEach(requiredPrompts, id: \.self) { prompt in
                    Button(prompt) { model.creativePrompt = prompt }
                        .buttonStyle(.borderless)
                        .font(Theme.Font.meta)
                        .padding(.horizontal, Theme.Spacing.eight)
                        .padding(.vertical, Theme.Spacing.four)
                        .background(Theme.Colors.accentSubtle, in: Capsule())
                }
            }

            DisclosureGroup("More musician-language starting points") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 185), spacing: Theme.Spacing.eight)],
                    alignment: .leading,
                    spacing: Theme.Spacing.eight
                ) {
                    ForEach(metaphorPrompts, id: \.self) { prompt in
                        Button(prompt) { model.creativePrompt = prompt }
                            .buttonStyle(.borderless)
                            .font(Theme.Font.meta)
                            .padding(.horizontal, Theme.Spacing.eight)
                            .padding(.vertical, Theme.Spacing.four)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.raised, in: Capsule())
                    }
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            scopeControls

            HStack {
                Picker("Asset boundary", selection: $model.assetAcceptance) {
                    ForEach(VocalAssetAcceptance.allCases, id: \.self) { acceptance in
                        Text(VocalWorkspacePresentation.assetAcceptanceLabel(acceptance))
                            .tag(acceptance)
                    }
                }
                .frame(maxWidth: 360)

                Spacer()

                Button("Interpret typed intent") {
                    callbacks.requestCreativeIntent(
                        model.creativePrompt,
                        model.creativeScope,
                        model.assetAcceptance
                    )
                    model.noteRequest(
                        "Typed creative interpretation requested; prompt text has not rendered or changed audio."
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!model.canRequestCreativeIntent)
            }

            if let scopeDraftError = model.scopeDraftError {
                Label(scopeDraftError, systemImage: "exclamationmark.triangle")
                    .font(Theme.Font.meta)
                    .foregroundStyle(.orange)
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private var scopeControls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack {
                Text("Scope")
                    .font(Theme.Font.section)
                Picker(
                    "Scope",
                    selection: Binding(
                        get: { model.creativeScope.kind },
                        set: { model.setCreativeScopeKind($0) }
                    )
                ) {
                    Text("Full source").tag(VocalScopeKind.fullSource)
                    Text("Seconds").tag(VocalScopeKind.seconds)
                    Text("Named section").tag(VocalScopeKind.namedSection)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                Spacer()
                VocalTag(text: VocalWorkspacePresentation.scopeLabel(model.creativeScope), accent: true)
            }

            if model.creativeScope.kind != .fullSource {
                HStack(spacing: Theme.Spacing.eight) {
                    TextField("Start seconds", text: $model.scopeStartText)
                        .onChange(of: model.scopeStartText) { _, _ in model.updateScopeDraft() }
                    TextField("End seconds", text: $model.scopeEndText)
                        .onChange(of: model.scopeEndText) { _, _ in model.updateScopeDraft() }
                    if model.creativeScope.kind == .namedSection {
                        TextField("Section ID", text: $model.scopeSectionID)
                            .onChange(of: model.scopeSectionID) { _, _ in model.updateScopeDraft() }
                        TextField("Section name", text: $model.scopeSectionName)
                            .onChange(of: model.scopeSectionName) { _, _ in model.updateScopeDraft() }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(Theme.Font.meta)
            }
        }
    }

    private func intentInspection(_ intent: VocalCreativeIntent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                    Text("Current typed interpretation")
                        .font(Theme.Font.section)
                    Text("Intent \(VocalWorkspacePresentation.shortID(intent.id)) · source \(VocalWorkspacePresentation.shortID(intent.sourceSnapshotID))")
                        .font(Theme.Font.data)
                        .foregroundStyle(Theme.Colors.mutedText)
                }
                Spacer()
                VocalTag(text: VocalWorkspacePresentation.words(intent.archetype.rawValue), accent: true)
                VocalTag(text: "Strength \(VocalWorkspacePresentation.percentage(intent.strength))")
            }

            HStack(spacing: Theme.Spacing.eight) {
                VocalTag(text: VocalWorkspacePresentation.words(intent.kind.rawValue))
                VocalTag(text: VocalWorkspacePresentation.scopeLabel(intent.scope))
                VocalTag(text: VocalWorkspacePresentation.editabilityLabel(intent.editability))
                VocalTag(text: VocalWorkspacePresentation.assetAcceptanceLabel(intent.assetAcceptance))
            }

            HStack(alignment: .top, spacing: Theme.Spacing.twelve) {
                intentColumn(
                    "Requested changes",
                    intent.desiredChanges.map {
                        "\(VocalWorkspacePresentation.words($0.direction.rawValue)) \(VocalWorkspacePresentation.words($0.aspect.rawValue)) · \(VocalWorkspacePresentation.percentage($0.strength))"
                    }
                )
                intentColumn(
                    "Preserve / prohibit",
                    intent.preservation.preserved.map {
                        "Preserve \(VocalWorkspacePresentation.words($0.rawValue))"
                    } + intent.preservation.prohibitedChanges.map {
                        "Prohibit \(VocalWorkspacePresentation.words($0.rawValue)) change"
                    }
                )
                intentColumn(
                    "Ambiguity / uncertainty",
                    intent.ambiguities + intent.uncertainties
                )
            }

            if !intent.aspectLocks.isEmpty {
                DisclosureGroup("Inherited aspect locks") {
                    VocalBulletList(items: intent.aspectLocks.map {
                        "\(VocalWorkspacePresentation.words($0.aspect.rawValue)) · \($0.reason) · scope \(VocalWorkspacePresentation.words($0.scopePolicy.rawValue))"
                    })
                    .padding(.top, Theme.Spacing.eight)
                }
                .font(Theme.Font.meta)
            }

            VocalHonestyNote(
                text: "This interpretation describes intent and constraints. Preference remains a level-matched listening judgment; metaphor labels are not acoustic reconstruction claims."
            )
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func intentColumn(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.four) {
            Text(title).font(Theme.Font.section)
            if items.isEmpty {
                Text("None recorded")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            } else {
                VocalBulletList(items: items, limit: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
