import AudioAnalysis
import SwiftUI
import VocalProduction

struct VocalAnalysisFeedbackView: View {
    @ObservedObject var model: VocalWorkspaceModel
    let callbacks: VocalWorkspaceCallbacks

    private let feedbackRatings: [VocalListeningRating] = [.better, .same, .worse, .notSure]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            VocalSectionHeader(
                index: "3",
                title: "Test take: measure, then listen",
                detail: "Measurements describe the supplied audio. Identity, acceptability, and preference stay listening-only."
            )

            if let report = model.sourceAwareAnalysis,
               let assessment = model.testTakeAssessment {
                analysisCard(report: report, assessment: assessment)
            } else {
                VocalHonestyNote(
                    text: "No current SourceAwareAnalysisReport and VocalTestTakeAssessment have been supplied. The workspace will not invent findings from the capture brief."
                )
            }

            feedbackCard
            revisionAncestryCard
        }
    }

    private func analysisCard(
        report: SourceAwareAnalysisReport,
        assessment: VocalTestTakeAssessment
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.twelve) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                    Text("Provided source-aware report")
                        .font(Theme.Font.section)
                    Text("\(VocalWorkspacePresentation.words(report.sourceClass.rawValue)) · analysis \(report.version)")
                        .font(Theme.Font.data)
                        .foregroundStyle(Theme.Colors.mutedText)
                }
                Spacer()
                if assessment.requiresImmediateStop {
                    VocalTag(text: "STOP CONDITION", accent: true)
                } else {
                    VocalTag(text: "NO STOP FINDING")
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                Text("Bounded findings")
                    .font(Theme.Font.section)
                ForEach(Array(assessment.findings.enumerated()), id: \.offset) { _, finding in
                    findingRow(finding)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                Text("Listening-only judgments")
                    .font(Theme.Font.section)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: Theme.Spacing.eight)],
                    alignment: .leading,
                    spacing: Theme.Spacing.eight
                ) {
                    ForEach(assessment.listeningOnlyJudgments, id: \.self) { judgment in
                        HStack(spacing: Theme.Spacing.four) {
                            Image(systemName: "ear")
                                .foregroundStyle(Theme.Colors.accent)
                            Text(VocalWorkspacePresentation.listeningLabel(judgment))
                                .font(Theme.Font.meta)
                            Spacer()
                            Text("LISTEN")
                                .font(Theme.Font.meta.weight(.semibold))
                                .foregroundStyle(Theme.Colors.mutedText)
                        }
                        .padding(Theme.Spacing.eight)
                        .instrumentSurface(.raised)
                    }
                }
            }

            DisclosureGroup("All source-aware measurements") {
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy6) {
                    ForEach(report.metrics.keys.sorted(), id: \.self) { identifier in
                        if let metric = report.metrics[identifier] {
                            metricRow(identifier: identifier, metric: metric)
                        }
                    }
                }
                .padding(.top, Theme.Spacing.eight)
            }
            .font(Theme.Font.meta)

            if !assessment.measurementLimitations.isEmpty {
                DisclosureGroup("Measurement limitations") {
                    VocalBulletList(items: assessment.measurementLimitations)
                        .padding(.top, Theme.Spacing.eight)
                }
                .font(Theme.Font.meta)
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    private func findingRow(_ finding: VocalCaptureFinding) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.eight) {
            Image(systemName: findingIcon(finding.severity))
                .foregroundStyle(finding.severity == .stop ? .red : Theme.Colors.accent)
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                HStack {
                    VocalTag(
                        text: VocalWorkspacePresentation.evidenceLabel(finding.evidenceKind),
                        accent: finding.evidenceKind == .measurementSupported
                    )
                    if let value = VocalWorkspacePresentation.findingValue(finding) {
                        Text(value)
                            .font(Theme.Font.data)
                            .help(finding.metricIdentifier ?? "No raw metric identifier")
                    }
                    Text("confidence \(VocalWorkspacePresentation.percentage(finding.confidence))")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.mutedText)
                }
                Text(finding.statement)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let first = finding.limitations.first {
                    Text("Limit: \(first)")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.mutedText)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.four)
    }

    private func metricRow(identifier: String, metric: SourceMetricValue) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.eight) {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                Text(VocalWorkspacePresentation.metricName(identifier))
                    .font(Theme.Font.meta)
                    .help(identifier)
                Text("confidence \(VocalWorkspacePresentation.percentage(metric.confidence))")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }
            Spacer()
            Text(VocalWorkspacePresentation.metricValue(metric))
                .font(Theme.Font.data)
        }
        .foregroundStyle(Theme.Colors.secondaryText)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
            HStack {
                Text("Compact listening feedback")
                    .font(Theme.Font.section)
                Spacer()
                Text("No acoustic classification is inferred")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.mutedText)
            }

            feedbackPicker(
                "Word clarity",
                value: Binding(
                    get: { model.captureFeedback.wordClarity },
                    set: { model.captureFeedback.wordClarity = $0 }
                )
            )
            feedbackPicker(
                "Room / reflections",
                value: Binding(
                    get: { model.captureFeedback.roomOrReflectionImpression },
                    set: { model.captureFeedback.roomOrReflectionImpression = $0 }
                )
            )
            feedbackPicker(
                "Voice naturalness",
                value: Binding(
                    get: { model.captureFeedback.voiceNaturalness },
                    set: { model.captureFeedback.voiceNaturalness = $0 }
                )
            )

            HStack {
                Text("Proximity")
                    .font(Theme.Font.meta)
                    .frame(width: 116, alignment: .leading)
                Picker(
                    "Proximity",
                    selection: Binding(
                        get: { model.captureFeedback.proximity },
                        set: { model.captureFeedback.proximity = $0 }
                    )
                ) {
                    ForEach(
                        [VocalProximityFeedback.tooClose, .balanced, .tooDistant, .notSure],
                        id: \.self
                    ) { value in
                        Text(VocalWorkspacePresentation.words(value.rawValue)).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            TextField(
                "Optional listening note",
                text: Binding(
                    get: { model.captureFeedback.note ?? "" },
                    set: { model.captureFeedback.note = $0.isEmpty ? nil : $0 }
                ),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...3)
            .padding(Theme.Spacing.eight)
            .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )

            Toggle(
                "Explicitly confirm this as my capture preference",
                isOn: Binding(
                    get: { model.captureFeedback.explicitlyConfirmAsPreference },
                    set: { model.captureFeedback.explicitlyConfirmAsPreference = $0 }
                )
            )
            .font(Theme.Font.meta)
            .toggleStyle(.switch)

            HStack {
                Button("Submit listening feedback") {
                    guard let selected = model.activeCaptureInterpretation else { return }
                    callbacks.submitCaptureListening(selected, model.captureFeedback)
                    model.noteRequest(
                        "Capture listening feedback submitted to the parent; no revision is assumed."
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.activeCaptureInterpretation == nil || !model.hasCaptureFeedback)

                Button("Request bounded revision") {
                    guard let selected = model.activeCaptureInterpretation else { return }
                    callbacks.requestCaptureRevision(
                        selected,
                        model.testTakeAssessment,
                        model.captureFeedback
                    )
                    model.noteRequest(
                        "A bounded capture revision was requested; the visible plan remains unchanged until the parent supplies one."
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accent)
                .disabled(model.activeCaptureInterpretation == nil || !model.hasCaptureFeedback)
            }
        }
        .padding(Theme.Spacing.twelve)
        .instrumentSurface(.raised, radius: Theme.Radius.medium)
    }

    @ViewBuilder
    private var revisionAncestryCard: some View {
        if let revision = model.latestCaptureRevision {
            VStack(alignment: .leading, spacing: Theme.Spacing.eight) {
                HStack {
                    Text("Revised capture plan ancestry")
                        .font(Theme.Font.section)
                    Spacer()
                    VocalTag(text: "NOT AUDITIONED HERE")
                }
                HStack(spacing: Theme.Spacing.four) {
                    ForEach(Array(revision.revisedInterpretation.ancestry.enumerated()), id: \.offset) { index, id in
                        Text(VocalWorkspacePresentation.shortID(id))
                            .font(Theme.Font.data)
                        Image(systemName: "chevron.right")
                            .font(Theme.Font.meta)
                            .foregroundStyle(Theme.Colors.mutedText)
                        if index == revision.revisedInterpretation.ancestry.count - 1 {
                            Text(VocalWorkspacePresentation.shortID(revision.revisedInterpretation.id))
                                .font(Theme.Font.data)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }
                VocalBulletList(items: revision.appliedReasons)
                Text("Assessment \(VocalWorkspacePresentation.shortID(revision.assessmentID)) · revision \(VocalWorkspacePresentation.shortID(revision.revisedInterpretation.revisionID))")
                    .font(Theme.Font.data)
                    .foregroundStyle(Theme.Colors.mutedText)
            }
            .padding(Theme.Spacing.twelve)
            .instrumentSurface(.raised, radius: Theme.Radius.medium)
        }
    }

    private func feedbackPicker(
        _ label: String,
        value: Binding<VocalListeningRating>
    ) -> some View {
        HStack {
            Text(label)
                .font(Theme.Font.meta)
                .frame(width: 116, alignment: .leading)
            Picker(label, selection: value) {
                ForEach(feedbackRatings, id: \.self) { rating in
                    Text(VocalWorkspacePresentation.words(rating.rawValue)).tag(rating)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func findingIcon(_ severity: VocalCaptureFindingSeverity) -> String {
        switch severity {
        case .information: "info.circle"
        case .caution: "exclamationmark.triangle"
        case .stop: "stop.circle.fill"
        }
    }
}
