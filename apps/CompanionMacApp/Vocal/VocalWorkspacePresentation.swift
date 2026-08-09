import AudioAnalysis
import Foundation
import PlanSchema
import VocalProduction

enum VocalWorkspacePresentation {
    static func words(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    static func shortID(_ id: UUID?) -> String {
        guard let id else { return "none" }
        return String(id.uuidString.lowercased().prefix(8))
    }

    static func percentage(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func evidenceLabel(_ kind: VocalEvidenceKind) -> String {
        switch kind {
        case .measurementSupported: "MEASURED"
        case .listeningOnly: "LISTENING ONLY"
        case .userReported: "USER REPORTED"
        case .professionalPracticeHeuristic: "PRACTICE HEURISTIC"
        case .productHeuristic: "PRODUCT HEURISTIC"
        case .unknown: "UNKNOWN"
        }
    }

    static func findingValue(_ finding: VocalCaptureFinding) -> String? {
        guard let value = finding.value else { return nil }
        let formatted = String(format: "%.4g", locale: Locale(identifier: "en_US_POSIX"), value)
        return [formatted, finding.unit].compactMap { $0 }.joined(separator: " ")
    }

    static func metricValue(_ metric: SourceMetricValue) -> String {
        let value = String(
            format: "%.4g",
            locale: Locale(identifier: "en_US_POSIX"),
            metric.value
        )
        return "\(value) \(words(metric.definition.unit.rawValue))"
    }

    static func metricName(_ identifier: String) -> String {
        switch identifier {
        case "vocal_high_frequency_burst_density_per_second":
            "High-frequency burst density"
        case "vocal_low_frequency_burst_density_per_second":
            "Low-frequency burst density"
        case "level_variability_p90_p10_db":
            "Gated level variability (P90–P10)"
        case "vocal_120_350_hz_energy_ratio":
            "Low-mid energy ratio (120–350 Hz)"
        case "vocal_200_500_hz_energy_ratio":
            "Energy ratio (200–500 Hz)"
        case "vocal_5_10_khz_energy_ratio":
            "Energy ratio (5–10 kHz)"
        case "vocal_10_20_khz_energy_ratio":
            "Energy ratio (10–20 kHz)"
        default:
            words(identifier)
        }
    }

    static func listeningLabel(_ judgment: VocalListeningJudgment) -> String {
        switch judgment {
        case .wordClarity: "Word clarity"
        case .plosivePerception: "Breath blast / plosive perception"
        case .sibilancePerception: "Sibilance perception"
        case .roomReflectionPerception: "Room / reflection impression"
        case .noiseIdentityAndAcceptability: "Noise identity and acceptability"
        case .pitchAndMelody: "Pitch and melody"
        case .performanceEmotion: "Performance emotion"
        case .proximityCharacter: "Proximity character"
        case .voiceNaturalness: "Voice naturalness"
        }
    }

    static func scopeLabel(_ scope: VocalCreativeScope) -> String {
        switch scope.kind {
        case .fullSource:
            return "Full source"
        case .seconds:
            guard let seconds = scope.seconds else { return "Invalid seconds scope" }
            return String(format: "%.2f–%.2f s", seconds.start, seconds.end)
        case .namedSection:
            guard let seconds = scope.seconds else { return "Invalid named scope" }
            return String(
                format: "%@ · %.2f–%.2f s",
                scope.sectionName ?? "Named section",
                seconds.start,
                seconds.end
            )
        }
    }

    static func processingBoundaryLabel(_ boundary: VocalProcessingBoundary) -> String {
        switch boundary {
        case .editableDeterministicDSP: "Editable deterministic DSP"
        case .editableModulationDSP: "Editable modulation DSP"
        case .scopedEditablePlanForOfflineRender: "Scoped editable plan · offline render only"
        case .analysisDrivenResynthesis: "Analysis-driven resynthesis proposal"
        case .renderedAsset: "Rendered derivative asset"
        }
    }

    static func editabilityLabel(_ editability: VocalEditability) -> String {
        switch editability {
        case .editableDeterministicDSP: "Editable deterministic DSP"
        case .editableAnalysisDrivenResynthesis: "Editable analysis-driven resynthesis"
        case .renderedAssetWithEditableSourcePlan: "Rendered asset with editable source plan"
        }
    }

    static func assetAcceptanceLabel(_ value: VocalAssetAcceptance) -> String {
        switch value {
        case .editableDSPOnly: "Editable DSP only"
        case .allowLocalRenderedAsset: "Allow local derivative asset"
        case .requireLocalRenderedAsset: "Require local derivative asset"
        case .rejectRenderedAssets: "Reject rendered assets"
        }
    }

    static func nodeLabel(_ node: ProcessingNode) -> String {
        let state = node.enabled ? "enabled" : "bypassed"
        let lock = node.locked ? " · locked" : ""
        return "\(words(node.type.rawValue)) · \(state)\(lock)"
    }

    static func authorityLabel(_ status: VocalCandidateAuthorityStatus) -> String {
        switch status {
        case .locallyValidated: "Locally validated plan"
        case .staleSourceReadOnly: "Stale source · read only"
        case .refused: "Refused"
        }
    }

    static func capturePlacement(_ placement: VocalMicPlacement) -> String {
        [
            words(placement.distance.rawValue),
            words(placement.height.rawValue),
            words(placement.angle.rawValue),
        ].joined(separator: " · ")
    }
}
