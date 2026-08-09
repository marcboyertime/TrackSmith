import SwiftUI

struct VocalWorkspaceView: View {
    @ObservedObject var model: VocalWorkspaceModel
    var callbacks = VocalWorkspaceCallbacks()
    var usesOwnScroll = true

    var body: some View {
        Group {
            if usesOwnScroll {
                ScrollView { workspaceContent }
            } else {
                workspaceContent
            }
        }
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.text)
        .tint(Theme.Colors.accent)
        .groupBoxStyle(InstrumentGroupBoxStyle())
    }

    private var workspaceContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twentyFour) {
            VStack(alignment: .leading, spacing: Theme.Spacing.four) {
                Text("Vocal workspace")
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.Colors.text)
                Text("One typed path from capture hypotheses to bounded creative proposals. You approve every comparison and action.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            workspaceMessages

            VocalCaptureBriefView(model: model, callbacks: callbacks)
            VocalCaptureInterpretationsView(model: model, callbacks: callbacks)
            VocalAnalysisFeedbackView(model: model, callbacks: callbacks)
            VocalGuideCreateHandoffView(model: model, callbacks: callbacks)
            VocalCreativeIntentView(model: model, callbacks: callbacks)
            VocalCreativeCandidatesView(model: model, callbacks: callbacks)

            VocalHonestyNote(
                text: "This workspace exposes typed requests and evidence boundaries. It does not claim Logic control, a completed render, or a listening result.",
                systemImage: "lock.shield"
            )
        }
        .padding(usesOwnScroll ? Theme.Spacing.twentyFour : 0)
    }

    @ViewBuilder
    private var workspaceMessages: some View {
        if let validationMessage = model.validationMessage {
            HStack(alignment: .top, spacing: Theme.Spacing.eight) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(validationMessage)
                    .font(Theme.Font.meta)
                Spacer()
                Button("Dismiss") { model.dismissMessages() }
                    .buttonStyle(.borderless)
            }
            .padding(Theme.Spacing.eight)
            .background(Theme.Colors.warningSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        } else if let requestNotice = model.requestNotice {
            HStack(alignment: .top, spacing: Theme.Spacing.eight) {
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(Theme.Colors.accent)
                Text(requestNotice)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                Button("Dismiss") { model.dismissMessages() }
                    .buttonStyle(.borderless)
            }
            .padding(Theme.Spacing.eight)
            .instrumentSurface(.raised)
        }
    }
}
