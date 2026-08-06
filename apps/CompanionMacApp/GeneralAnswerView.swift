import PlanSchema
import ProductionTutor
import SwiftUI

/// Renders a validated open-domain answer: direct answer first, then the one
/// recommended move, then alternatives and their tradeoffs, then evidence.
/// Depth follows the user's explanation setting; detail stays behind
/// disclosure so the default view is short.
struct GeneralAnswerView: View {
    let outcome: GeneralTutorOutcome
    let depth: TutorExplanationDepth
    /// Starting a guided experiment is only offered when a reviewed procedure
    /// backs the option; the closure is nil when no lesson can be started.
    var startExperiment: ((String) -> Void)?

    private var answer: GeneralTutorAnswerContract { outcome.answer }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            interpretationHeader
            directAnswerCard
            if let clarification = answer.clarificationQuestion {
                clarificationCard(clarification)
            }
            if !answer.unsupportedCapabilities.isEmpty {
                unsupportedCard
            }
            if let first = answer.recommendedFirstMove, answer.answerMode == .groundedAnswer {
                firstMoveCard(first)
            }
            if !answer.strategyOptions.isEmpty {
                strategySection
            }
            if !answer.contradictionDisclosures.isEmpty {
                contradictionSection
            }
            detailDisclosures
            evidenceFooter
        }
    }

    // MARK: - Header

    private var interpretationHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(kindLabel(answer.questionKind).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            if !answer.domains.isEmpty {
                Text(answer.domains.prefix(3).map(domainLabel).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(confidenceLabel(answer.confidenceClass))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var directAnswerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(answer.directAnswer)
                .font(.body)
                .textSelection(.enabled)
            if !answer.assumptions.isEmpty {
                DisclosureGroup("What I am assuming") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(answer.assumptions, id: \.self) { assumption in
                            Text("• " + assumption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func clarificationCard(_ question: String) -> some View {
        Label(question, systemImage: "questionmark.circle")
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var unsupportedCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(answer.unsupportedCapabilities, id: \.self) { capability in
                Label("Not something TrackSmith does: \(capability)", systemImage: "hand.raised")
                    .font(.caption)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func firstMoveCard(_ move: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRY THIS FIRST")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text(move).font(.callout)
            if !answer.whatToListenFor.isEmpty {
                Label(answer.whatToListenFor.prefix(2).joined(separator: " "), systemImage: "ear")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let stop = answer.stopConditions.first {
                Label("Stop when: \(stop)", systemImage: "hand.raised.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Strategies

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ways to approach it")
                .font(.subheadline.weight(.semibold))
            ForEach(Array(answer.strategyOptions.enumerated()), id: \.offset) { index, option in
                strategyCard(option, isBest: index == 0)
            }
        }
    }

    private func strategyCard(_ option: GeneralStrategyOption, isBest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.label).font(.callout.weight(.medium))
                if isBest {
                    Text("BEST FIRST")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
                Spacer()
            }
            Text(option.simplestTest).font(.caption)
            if depth != .simple {
                if !option.tradeoffs.isEmpty {
                    Label(option.tradeoffs.joined(separator: " "), systemImage: "arrow.left.arrow.right")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if !option.preservationRisks.isEmpty {
                    Label(option.preservationRisks.joined(separator: " "), systemImage: "shield")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Label("Stop when: \(option.stoppingRule)", systemImage: "hand.raised.circle")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            // Only a reviewed procedure can start an exact guided experiment.
            if let procedureID = option.relatedProcedureIDs.first, let startExperiment {
                Button("Start guided experiment") { startExperiment(procedureID) }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var contradictionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Credible sources disagree", systemImage: "exclamationmark.bubble")
                .font(.subheadline.weight(.semibold))
            ForEach(answer.contradictionDisclosures, id: \.self) { disclosure in
                Text(disclosure).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Detail and evidence

    @ViewBuilder private var detailDisclosures: some View {
        if !answer.preservationChecks.isEmpty {
            DisclosureGroup("What to preserve") {
                bullets(answer.preservationChecks)
            }.font(.caption)
        }
        if !answer.risksAndSideEffects.isEmpty {
            DisclosureGroup("What could go wrong") {
                bullets(answer.risksAndSideEffects)
            }.font(.caption)
        }
        if !answer.nonDSPPossibilities.isEmpty {
            DisclosureGroup("Non-processing options") {
                bullets(answer.nonDSPPossibilities)
            }.font(.caption)
        }
        if !answer.currentContextLimitations.isEmpty {
            DisclosureGroup("What TrackSmith cannot see") {
                bullets(answer.currentContextLimitations)
            }.font(.caption)
        }
    }

    private func bullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(Set(items)).sorted(), id: \.self) { item in
                Text("• " + item).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var evidenceFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The audio-honesty statement: says exactly what the capture did
            // or did not contribute.
            Label(answer.audioInfluence.statement, systemImage: "waveform.badge.magnifyingglass")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !answer.sourceIDs.isEmpty {
                DisclosureGroup("Sources (\(answer.sourceIDs.count))") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(answer.sourceIDs, id: \.self) { id in
                            sourceRow(id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
            if let principle = answer.teachingPrinciple {
                Label(principle, systemImage: "graduationcap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if answer.listeningRemainsDecisive {
                Text("Listening remains decisive. None of this proves a cause.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func sourceRow(_ id: String) -> some View {
        if let source = outcome.retrieved.claims.first(where: { $0.sourceID == id }) {
            Text("• \(id) — \(evidenceLabel(source.evidenceClass))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("• \(id)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Labels

    private func kindLabel(_ kind: GeneralQuestionKind) -> String {
        switch kind {
        case .troubleshootProblem: "Troubleshooting"
        case .achieveSoundOrFeeling: "Achieving a sound"
        case .explainConcept: "Concept"
        case .productionStrategy: "Strategy"
        case .compareOptions: "Comparing options"
        case .exactWorkflowHelp: "Workflow"
        case .planSession: "Planning"
        case .diagnoseTradeoff: "Tradeoff"
        case .researchUnfamiliar: "Needs current research"
        }
    }

    private func confidenceLabel(_ confidence: AnswerConfidenceClass) -> String {
        switch confidence {
        case .reviewedExactProcedure: "reviewed exact procedure"
        case .sourceGroundedStrategy: "source-grounded strategy"
        case .professionalPracticeHeuristic: "professional practice"
        case .provisionalResearchResult: "provisional research"
        case .userConfirmedPersonalResult: "your confirmed result"
        case .unsupportedOrUnresolved: "unresolved"
        }
    }

    private func evidenceLabel(_ evidence: GeneralEvidenceClass) -> String {
        switch evidence {
        case .documentedBehavior: "documented behavior"
        case .measuredBehavior: "measured"
        case .technicalInference: "inference"
        case .professionalPracticeHeuristic: "professional practice"
        case .subjectivePreference: "subjective preference"
        case .userConfirmedPersonalResult: "your result"
        case .provisionalResearch: "provisional"
        case .unresolvedOrDisputed: "disputed"
        }
    }

    private func domainLabel(_ domain: ProductionDomain) -> String {
        domain.rawValue
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .lowercased()
    }
}
