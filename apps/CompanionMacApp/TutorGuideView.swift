import PlanSchema
import ProductionTutor
import SwiftUI

/// Guide Me: a structured studio workflow, not a chat transcript. One active
/// step at a time, simple language first, technical detail behind disclosure,
/// visible evidence grounding and uncertainty, and an undo for everything.
struct TutorGuideView: View {
    @ObservedObject var session: CompanionSessionModel
    @ObservedObject var tutor: TutorSessionModel
    @State private var isStartingLesson = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let reason = tutor.engineUnavailableReason {
                Label(reason, systemImage: "exclamationmark.octagon")
                    .foregroundStyle(.red)
            } else {
                evidenceBanner
                requestPanel
                if let lesson = tutor.lesson {
                    lessonContent(lesson)
                }
            }
        }
        .onChange(of: session.captureArtifact) { _, _ in reconcileAuthority() }
        .onChange(of: session.instances) { _, _ in reconcileAuthority() }
    }

    private func reconcileAuthority() {
        tutor.markAudioEvidenceHistoricalIfNeeded(
            authorityIsLive: session.tutorAuthorityIsLive(tutor.lesson?.authority)
        )
    }

    // MARK: - Evidence banner

    private var evidenceBanner: some View {
        GroupBox {
            HStack(spacing: 10) {
                Image(systemName: evidenceSymbol)
                    .foregroundStyle(evidenceColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(evidenceTitle).font(.subheadline.weight(.semibold))
                    Text(evidenceDetail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private var lessonUsesLiveAudio: Bool {
        guard let lesson = tutor.lesson else {
            return session.captureArtifact != nil
        }
        return lesson.evidenceMode == .audioGrounded && !lesson.audioEvidenceIsHistorical
    }

    private var evidenceSymbol: String {
        if let lesson = tutor.lesson, lesson.evidenceMode == .audioGrounded {
            return lesson.audioEvidenceIsHistorical ? "clock.arrow.circlepath" : "waveform.badge.magnifyingglass"
        }
        return session.captureArtifact != nil ? "waveform.badge.magnifyingglass" : "waveform.slash"
    }

    private var evidenceColor: Color {
        if let lesson = tutor.lesson, lesson.evidenceMode == .audioGrounded {
            return lesson.audioEvidenceIsHistorical ? .orange : .green
        }
        return session.captureArtifact != nil ? .green : .orange
    }

    private var evidenceTitle: String {
        if let lesson = tutor.lesson {
            switch (lesson.evidenceMode, lesson.audioEvidenceIsHistorical) {
            case (.audioGrounded, false): return "Grounded in your current capture"
            case (.audioGrounded, true): return "Capture evidence is historical"
            case (.userReportedOnly, _): return "General guidance — no audio evidence"
            }
        }
        return session.captureArtifact != nil
            ? "Current audio evidence is available"
            : "No recent capture"
    }

    private var evidenceDetail: String {
        if let lesson = tutor.lesson {
            switch (lesson.evidenceMode, lesson.audioEvidenceIsHistorical) {
            case (.audioGrounded, false):
                return "Local measurements from your recent capture inform the hypotheses. They are descriptive and cannot prove a cause."
            case (.audioGrounded, true):
                return "The Audio Unit or capture changed since this lesson started. Its measured statements describe the earlier capture, not the live session."
            case (.userReportedOnly, _):
                return "This advice is based only on your description. Analyze recent playback for audio-grounded hypotheses."
            }
        }
        return session.captureArtifact != nil
            ? "Starting a lesson will use the analyzed recent capture as supporting evidence."
            : "Insert TrackSmith on the vocal track, play the section, and use Analyze Recent Playback above for grounded guidance. You can still start a general lesson now."
    }

    // MARK: - Request panel

    private var requestPanel: some View {
        GroupBox("What do you want help with?") {
            VStack(alignment: .leading, spacing: 10) {
                TextField(
                    "Describe the problem or the sound you want",
                    text: $tutor.requestText,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                HStack {
                    ForEach(
                        ["I sound nasal", "It became nasal after I compressed it", "The s sounds are too sharp"],
                        id: \.self
                    ) { chip in
                        Button(chip) { tutor.requestText = chip }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                }
                chainPanel
                HStack {
                    Picker("Explanation", selection: $tutor.explanationDepth) {
                        Text("Simple").tag(TutorExplanationDepth.simple)
                        Text("Standard").tag(TutorExplanationDepth.standard)
                        Text("Technical").tag(TutorExplanationDepth.technical)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                    Spacer()
                    Button(tutor.lesson == nil ? "Start Lesson" : "Start New Lesson") {
                        startLesson()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isStartingLesson
                            || tutor.requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                if !tutor.restoredNote.isEmpty {
                    Text(tutor.restoredNote).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var chainPanel: some View {
        DisclosureGroup("What is already on this channel? (your report — TrackSmith cannot see Logic inserts)") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Chain", selection: $tutor.chainStatus) {
                    Text("I don't know").tag(TutorUserReportedChain.Status.unknown)
                    Text("Nothing").tag(TutorUserReportedChain.Status.none)
                    Text("These processors:").tag(TutorUserReportedChain.Status.reported)
                }
                .pickerStyle(.segmented)
                if tutor.chainStatus == .reported {
                    HStack(spacing: 6) {
                        ForEach(TutorReportedProcessor.allCases, id: \.self) { processor in
                            Toggle(
                                processorLabel(processor),
                                isOn: Binding(
                                    get: { tutor.chainProcessors.contains(processor) },
                                    set: { enabled in
                                        if enabled { tutor.chainProcessors.insert(processor) }
                                        else { tutor.chainProcessors.remove(processor) }
                                    }
                                )
                            )
                            .toggleStyle(.button)
                            .controlSize(.small)
                        }
                    }
                }
                Text("This is user-reported context, never observed state.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    private func processorLabel(_ processor: TutorReportedProcessor) -> String {
        switch processor {
        case .eq: "EQ"
        case .compressor: "Compressor"
        case .deEsser: "De-esser"
        case .gateOrExpander: "Gate/Expander"
        case .pitchProcessor: "Pitch"
        case .reverb: "Reverb"
        case .delay: "Delay"
        }
    }

    private func startLesson() {
        isStartingLesson = true
        let sourceType = session.sourceType
        Task {
            defer { isStartingLesson = false }
            var capture: TutorCaptureContext?
            do {
                capture = try await session.tutorCaptureContext()
            } catch {
                capture = nil
            }
            tutor.startLesson(sourceType: sourceType, capture: capture)
        }
    }

    // MARK: - Lesson content

    @ViewBuilder private func lessonContent(_ lesson: TutorLessonState) -> some View {
        if lesson.status == .awaitingClarification, let question = lesson.clarificationQuestion {
            GroupBox("One quick question") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(question)
                    Text("Answer by editing your request above and starting the lesson again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }

        if !lesson.hypotheses.isEmpty {
            hypothesesPanel(lesson)
        }

        if !lesson.unresolvedLimitations.isEmpty {
            GroupBox("What the tutor will not do here") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lesson.unresolvedLimitations, id: \.self) { limitation in
                        Label(limitation, systemImage: "hand.raised")
                            .font(.caption)
                    }
                }
                .padding(8)
            }
        }

        if let step = lesson.activeStep, lesson.status == .activeStep {
            stepCard(step, lesson: lesson)
        }

        if !tutor.statusMessage.isEmpty {
            Text(tutor.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let summary = lesson.finalSummary {
            summaryCard(summary, lesson: lesson)
        }
    }

    private func hypothesesPanel(_ lesson: TutorLessonState) -> some View {
        GroupBox("Possible causes — deliberately more than one") {
            VStack(alignment: .leading, spacing: 8) {
                Text(tutor.formatter.hypothesisIntro(for: lesson))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(lesson.hypotheses.enumerated()), id: \.offset) { index, hypothesis in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: hypothesisSymbol(hypothesis.status))
                            .foregroundStyle(hypothesisColor(hypothesis.status))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1). \(hypothesis.summary)")
                                .font(.caption)
                            if hypothesis.status != .open {
                                Text(hypothesisStatusLabel(hypothesis.status))
                                    .font(.caption2)
                                    .foregroundStyle(hypothesisColor(hypothesis.status))
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func hypothesisSymbol(_ status: TutorHypothesisStatus) -> String {
        switch status {
        case .open: "questionmark.circle"
        case .strengthened: "arrow.up.circle.fill"
        case .weakened: "arrow.down.circle"
        case .contraindicated: "xmark.circle"
        }
    }

    private func hypothesisColor(_ status: TutorHypothesisStatus) -> Color {
        switch status {
        case .open: .secondary
        case .strengthened: .green
        case .weakened: .orange
        case .contraindicated: .red
        }
    }

    private func hypothesisStatusLabel(_ status: TutorHypothesisStatus) -> String {
        switch status {
        case .open: ""
        case .strengthened: "Your feedback makes this more likely"
        case .weakened: "Your feedback makes this less likely"
        case .contraindicated: "Set aside for this session after a worse result"
        }
    }

    // MARK: - Step card

    private func stepCard(_ step: TutorStep, lesson: TutorLessonState) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(progressLabel(step, lesson: lesson))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text("You perform every action — TrackSmith never touches Logic")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(step.title).font(.title3.weight(.semibold))
                Text(step.instruction)

                if !step.substeps.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(step.substeps.enumerated()), id: \.offset) { index, substep in
                            Text("\(index + 1). \(substep)")
                        }
                    }
                    .font(.callout)
                }

                Label {
                    Text(step.listenFor)
                } icon: {
                    Image(systemName: "ear")
                }
                .font(.callout)

                Text(tutor.formatter.explanation(for: step, depth: .simple))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if tutor.explanationDepth != .simple {
                    DisclosureGroup("Why this works") {
                        Text(step.technicalExplanation)
                            .font(.caption)
                            .padding(.top, 4)
                    }
                    .font(.caption)
                }
                DisclosureGroup("Producer lesson") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(step.concepts, id: \.self) { concept in
                            Label(tutor.formatter.conceptLabel(concept), systemImage: "graduationcap")
                                .font(.caption)
                        }
                        if !step.uncertainty.isEmpty {
                            Text("Uncertainty: " + step.uncertainty.joined(separator: " "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)

                if let location = step.location {
                    DisclosureGroup("Where to find it") {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Logic Pro \(location.logicVersion) · \(location.workArea)")
                            Text(location.navigationLabels.joined(separator: " → "))
                                .font(.caption.monospaced())
                            Text(location.requiredFocusOrSelection)
                            if location.verification == .documentary {
                                Text("Path from Apple documentation; not yet re-verified on this machine.")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                        .padding(.top, 4)
                    }
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Label("Stop: \(step.stopCondition)", systemImage: "hand.raised")
                    Label("Could go wrong: \(step.commonSideEffect)", systemImage: "exclamationmark.triangle")
                    Label("Undo: \(step.undoInstruction)", systemImage: "arrow.uturn.backward")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                feedbackBar(step)
            }
            .padding(10)
        }
    }

    private func progressLabel(_ step: TutorStep, lesson: TutorLessonState) -> String {
        let total = lesson.steps.count
        let index = (lesson.steps.firstIndex { $0.id == step.id } ?? 0) + 1
        return "STEP \(index) OF \(total) · EXPERIMENT \(max(lesson.attemptedProcedureIDs.count, 1))"
    }

    private func feedbackBar(_ step: TutorStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What happened?").font(.caption.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(step.supportedFeedback, id: \.self) { feedback in
                    Button(feedbackLabel(feedback)) { tutor.send(feedback) }
                        .buttonStyle(.borderedProminent)
                        .tint(feedbackTint(feedback))
                        .controlSize(.regular)
                        .accessibilityLabel(feedbackAccessibilityLabel(feedback))
                }
            }
        }
    }

    private func feedbackLabel(_ feedback: TutorFeedback) -> String {
        switch feedback {
        case .better: "Better"
        case .worse: "Worse"
        case .noChange: "No change"
        case .notSure: "Not sure"
        case .notApplicable: "Not applicable"
        case .cannotFindControl: "Can't find it"
        case .done: "Done"
        case .undo: "Undo"
        }
    }

    private func feedbackAccessibilityLabel(_ feedback: TutorFeedback) -> String {
        switch feedback {
        case .better: "The change made it better"
        case .worse: "The change made it worse"
        case .noChange: "No audible change"
        case .notSure: "Not sure yet"
        case .notApplicable: "This step does not apply"
        case .cannotFindControl: "I cannot find this control in Logic"
        case .done: "This step is done"
        case .undo: "Show me how to undo this step"
        }
    }

    private func feedbackTint(_ feedback: TutorFeedback) -> Color {
        switch feedback {
        case .better: .green
        case .worse: .red
        case .undo: .orange
        default: .accentColor
        }
    }

    // MARK: - Summary

    private func summaryCard(_ summary: TutorLessonSummary, lesson: TutorLessonState) -> some View {
        GroupBox("What you learned") {
            VStack(alignment: .leading, spacing: 8) {
                Label(summary.whatChanged, systemImage: "checkmark.circle")
                Label(summary.likelyCause, systemImage: "lightbulb")
                ForEach(summary.whatDidNotHelp, id: \.self) { item in
                    Label(item, systemImage: "minus.circle").foregroundStyle(.secondary)
                }
                ForEach(summary.whatWasPreserved, id: \.self) { item in
                    Label(item, systemImage: "lock.shield").foregroundStyle(.secondary)
                }
                Text(summary.principleToRemember)
                    .font(.callout.weight(.semibold))
                    .padding(.top, 4)
                ForEach(summary.remainingUncertainty, id: \.self) { item in
                    Text(item).font(.caption).foregroundStyle(.secondary)
                }
                if !lesson.conceptsPracticed.isEmpty {
                    Divider()
                    Text("Concepts practiced").font(.caption.weight(.semibold))
                    ForEach(lesson.conceptsPracticed, id: \.self) { concept in
                        Label(tutor.formatter.conceptLabel(concept), systemImage: "graduationcap")
                            .font(.caption)
                    }
                }
            }
            .font(.callout)
            .padding(8)
        }
    }
}
