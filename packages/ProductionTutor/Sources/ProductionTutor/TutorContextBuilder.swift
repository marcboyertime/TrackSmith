import AudioAnalysis
import Foundation
import PlanSchema

/// Bounded, deterministic context for one tutor lesson. Measured statements
/// come only from the local `SourceAwareAnalysisReport`; their wording keeps
/// the analyzer's limits explicit (descriptive, not phoneme-aware).
public struct TutorLessonContext: Equatable, Sendable {
    public var evidenceMode: TutorEvidenceMode
    public var authority: TutorAuthorityReference?
    public var evidence: [TutorEvidenceStatement]

    public init(
        evidenceMode: TutorEvidenceMode,
        authority: TutorAuthorityReference?,
        evidence: [TutorEvidenceStatement]
    ) {
        self.evidenceMode = evidenceMode
        self.authority = authority
        self.evidence = evidence
    }
}

public struct TutorContextBuilder: Sendable {
    public static let maximumEvidenceStatements = 8

    public init() {}

    public func build(
        sourceType: SourceType,
        analysis: SourceAwareAnalysisReport?,
        authority: TutorAuthorityReference?,
        chain: TutorUserReportedChain
    ) -> TutorLessonContext {
        var evidence: [TutorEvidenceStatement] = []

        switch chain.status {
        case .unknown:
            evidence.append(.init(
                statement: "You have not described the existing processing chain; TrackSmith cannot inspect Logic inserts, so chain-dependent causes stay open.",
                provenanceClass: .userReported,
                relationship: .doesNotResolve,
                confidence: 0.5
            ))
        case .none:
            evidence.append(.init(
                statement: "You reported that no processing is active on this channel, so existing-processing causes are less likely (user-reported, not observed).",
                provenanceClass: .userReported,
                relationship: .contradicts,
                confidence: 0.6
            ))
        case .reported:
            let names = chain.processors.map(\.rawValue).sorted().joined(separator: ", ")
            evidence.append(.init(
                statement: "You reported these processors on the channel: \(names). This is user-reported, not observed by TrackSmith.",
                provenanceClass: .userReported,
                relationship: .supports,
                confidence: 0.6
            ))
        }

        guard let analysis else {
            evidence.append(.init(
                statement: "No recent capture is available, so this guidance is general and not grounded in your current audio.",
                provenanceClass: .trackSmithProductHeuristic,
                relationship: .unavailable,
                confidence: 0.9
            ))
            return TutorLessonContext(
                evidenceMode: .userReportedOnly,
                authority: nil,
                evidence: evidence
            )
        }

        evidence.append(.init(
            statement: "A recent capture was analyzed locally. The analyzer is descriptive: it measures averaged spectral and dynamic behavior and is not phoneme-aware, so it cannot prove or disprove nasality.",
            provenanceClass: .locallyMeasured,
            relationship: .doesNotResolve,
            confidence: 0.8
        ))

        let interesting = [
            "vocal_200_500_hz_energy_ratio",
            "vocal_120_350_hz_energy_ratio",
            "maximum_third_octave_concentration_ratio",
            "level_variability_p90_p10_db",
        ]
        for identifier in interesting {
            guard evidence.count < Self.maximumEvidenceStatements,
                  let metric = analysis.metrics[identifier] else { continue }
            evidence.append(.init(
                statement: "Measured \(identifier). This describes averaged energy distribution; it is consistent with several competing causes and does not identify one.",
                provenanceClass: .locallyMeasured,
                relationship: .doesNotResolve,
                metricIdentifier: identifier,
                value: metric.value,
                unit: metricUnitLabel(metric.definition.unit),
                confidence: metric.confidence
            ))
        }

        return TutorLessonContext(
            evidenceMode: .audioGrounded,
            authority: authority,
            evidence: Array(evidence.prefix(Self.maximumEvidenceStatements))
        )
    }

    private func metricUnitLabel(_ unit: MetricUnit) -> String {
        String(describing: unit)
    }
}
