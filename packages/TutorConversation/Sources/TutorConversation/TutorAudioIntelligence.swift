import AudioAnalysis
import CryptoKit
import DSPCore
import Foundation
import PlanSchema

/// The evidence vocabulary is deliberately narrower than product language. A
/// result describes what a component received and measured; it never upgrades
/// a measurement into a listening, masking, or quality claim.
public enum TutorAudioEvidenceKind: String, Codable, CaseIterable, Sendable {
    case modelHeardWaveform
    case localMeasurement
    case userConfirmation
    case userReport
    case logicObservation
    case reviewedKnowledge
    case separatedSourceEstimate
    case structureEstimate
    case inference
    case unavailable
}

public enum TutorAudioTask: String, Codable, CaseIterable, Sendable {
    case identity
    case gainLoudness
    case tonalTilt
    case dynamics
    case stereoRelation
}

/// Whether supplied bytes were successfully bound to the immutable capture.
/// `receivedOriginalWaveformBytes` is true only for `captureBoundExactWAV`.
/// This status retains the narrower truth that bytes reached the provider even
/// when they were mismatched, undecodable, or cancelled before binding.
public enum TutorWaveformBindingStatus: String, Codable, Sendable {
    case captureBoundExactWAV
    case bytesReceivedHashMismatch
    case bytesReceivedUndecodable
    case cancelledBeforeBinding
}

public struct TutorAudioTaskCapability: Codable, Equatable, Sendable {
    public var task: TutorAudioTask
    public var calibrated: Bool
    public var detail: String

    public init(task: TutorAudioTask, calibrated: Bool, detail: String) {
        self.task = task
        self.calibrated = calibrated
        self.detail = detail
    }
}

public struct TutorAudioCaptureIdentity: Codable, Equatable, Sendable {
    public var captureSnapshotID: UUID
    public var sha256: String
    public var sourceType: SourceType
    public var instanceID: UUID
    public var runtimeEpoch: UUID
    public var scopeDescription: String
    public var durationSeconds: Double
    public var capturedAt: Date
    public var formatDescription: String?

    public init(_ snapshot: TutorCaptureSnapshot) {
        captureSnapshotID = snapshot.captureSnapshotID
        sha256 = snapshot.sha256
        sourceType = snapshot.sourceType
        instanceID = snapshot.instanceID
        runtimeEpoch = snapshot.runtimeEpoch
        scopeDescription = snapshot.scopeDescription
        durationSeconds = snapshot.durationSeconds
        capturedAt = snapshot.capturedAt
        formatDescription = snapshot.formatDescription
    }
}

public struct TutorAudioObservation: Codable, Equatable, Sendable {
    public var identifier: String
    public var value: Double?
    public var unit: String?
    public var evidence: TutorAudioEvidenceKind
    public var detail: String

    public init(identifier: String, value: Double? = nil, unit: String? = nil, evidence: TutorAudioEvidenceKind, detail: String) {
        self.identifier = identifier
        self.value = value?.isFinite == true ? value : nil
        self.unit = unit
        self.evidence = evidence
        self.detail = detail
    }
}

public struct TutorAudioIntelligenceResult: Codable, Equatable, Sendable {
    public var version: String
    public var capture: TutorAudioCaptureIdentity
    public var providerIdentifier: String
    public var modelIdentifier: String?
    public var checkpointIdentifier: String?
    public var receivedOriginalWaveformBytes: Bool
    public var waveformBindingStatus: TutorWaveformBindingStatus?
    public var sourceProvenance: String
    public var capabilities: [TutorAudioTaskCapability]
    public var observations: [TutorAudioObservation]
    public var alternatives: [String]
    public var limitations: [String]
    public var runtimeMilliseconds: Int
    public var failure: String?
    public var cancelled: Bool
    public var deadlineSeconds: Double?

    public init(
        capture: TutorAudioCaptureIdentity,
        providerIdentifier: String,
        modelIdentifier: String? = nil,
        checkpointIdentifier: String? = nil,
        receivedOriginalWaveformBytes: Bool,
        waveformBindingStatus: TutorWaveformBindingStatus? = nil,
        sourceProvenance: String,
        capabilities: [TutorAudioTaskCapability],
        observations: [TutorAudioObservation] = [],
        alternatives: [String] = [],
        limitations: [String] = [],
        runtimeMilliseconds: Int = 0,
        failure: String? = nil,
        cancelled: Bool = false,
        deadlineSeconds: Double? = nil
    ) {
        version = "1.0"
        self.capture = capture
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.checkpointIdentifier = checkpointIdentifier
        self.receivedOriginalWaveformBytes = receivedOriginalWaveformBytes
        self.waveformBindingStatus = waveformBindingStatus
        self.sourceProvenance = sourceProvenance
        self.capabilities = capabilities
        self.observations = Array(observations.prefix(32))
        self.alternatives = Array(alternatives.prefix(8))
        self.limitations = Array(limitations.prefix(12))
        self.runtimeMilliseconds = max(0, runtimeMilliseconds)
        self.failure = failure
        self.cancelled = cancelled
        self.deadlineSeconds = deadlineSeconds?.isFinite == true ? deadlineSeconds : nil
    }
}

public protocol TutorAudioIntelligenceProvider: Sendable {
    var providerIdentifier: String { get }
    func analyze(wavData: Data, capture: TutorCaptureSnapshot) async -> TutorAudioIntelligenceResult
}

/// A deterministic specialist for exact local WAV bytes. It is intentionally
/// not a model listener and has calibration only for the synthetic lab tasks.
public struct LocalWaveformSpecialist: TutorAudioIntelligenceProvider, Sendable {
    public let providerIdentifier = "tracksmith-local-waveform-specialist-v1"

    public init() {}

    public static let capabilities: [TutorAudioTaskCapability] = [
        .init(task: .identity, calibrated: true, detail: "Exact SHA-256 and WAV decode are checked in the deterministic lab."),
        .init(task: .gainLoudness, calibrated: true, detail: "Relative RMS/gain direction is calibrated only on synthetic fixtures."),
        .init(task: .tonalTilt, calibrated: true, detail: "Low/high energy relation is calibrated only on synthetic fixtures."),
        .init(task: .dynamics, calibrated: true, detail: "Crest-factor direction is calibrated only on synthetic fixtures."),
        .init(task: .stereoRelation, calibrated: true, detail: "Channel correlation/side relation is calibrated only on synthetic fixtures."),
    ]

    public func analyze(wavData: Data, capture: TutorCaptureSnapshot) async -> TutorAudioIntelligenceResult {
        let started = ContinuousClock.now
        let identity = TutorAudioCaptureIdentity(capture)
        guard !Task.isCancelled else {
            return result(identity, binding: .cancelledBeforeBinding, runtime: 0, failure: "Local waveform analysis was cancelled.", cancelled: true)
        }
        let digest = SHA256.hash(data: wavData).map { String(format: "%02x", $0) }.joined()
        guard digest == capture.sha256 else {
            return result(identity, binding: .bytesReceivedHashMismatch, runtime: 0, failure: "Received WAV bytes did not match the capture hash.")
        }
        do {
            let buffer = try WAVFile.read(data: wavData)
            guard !Task.isCancelled else {
                return result(identity, binding: .cancelledBeforeBinding, runtime: elapsed(started), failure: "Local waveform analysis was cancelled.", cancelled: true)
            }
            let report = SourceAwareAudioAnalyzer().analyze(buffer, as: analysisClass(capture.sourceType))
            let observations = report.metrics.values.sorted { $0.definition.identifier < $1.definition.identifier }.prefix(16).map {
                TutorAudioObservation(
                    identifier: $0.definition.identifier,
                    value: $0.value,
                    unit: $0.definition.unit.rawValue,
                    evidence: .localMeasurement,
                    detail: "Exact local WAV measurement. \($0.definition.knownFailureModes.prefix(1).joined())"
                )
            }
            return TutorAudioIntelligenceResult(
                capture: identity,
                providerIdentifier: providerIdentifier,
                receivedOriginalWaveformBytes: true,
                waveformBindingStatus: .captureBoundExactWAV,
                sourceProvenance: "Exact hash-validated local WAV bytes decoded by public WAVFile.",
                capabilities: Self.capabilities,
                observations: observations,
                alternatives: ["A measurement can reflect arrangement, performance, capture chain, and existing processing."],
                limitations: [
                    "This component made local measurements; it did not hear as a model or person.",
                    "It does not separate sources, infer whole-mix masking, or assess subjective improvement.",
                ],
                runtimeMilliseconds: elapsed(started)
            )
        } catch {
            return result(identity, binding: .bytesReceivedUndecodable, runtime: elapsed(started), failure: "Received capture-hash-matching WAV bytes could not be decoded by the local specialist.")
        }
    }

    private func result(_ capture: TutorAudioCaptureIdentity, binding: TutorWaveformBindingStatus, runtime: Int, failure: String, cancelled: Bool = false) -> TutorAudioIntelligenceResult {
        TutorAudioIntelligenceResult(
            capture: capture, providerIdentifier: providerIdentifier, receivedOriginalWaveformBytes: binding == .captureBoundExactWAV,
            waveformBindingStatus: binding,
            sourceProvenance: binding == .bytesReceivedHashMismatch
                ? "WAV bytes reached the local specialist but did not match the capture hash."
                : binding == .bytesReceivedUndecodable
                    ? "Capture-hash-matching WAV bytes reached the local specialist but could not be decoded."
                    : "Local waveform analysis was cancelled before exact capture binding completed.", capabilities: Self.capabilities,
            limitations: ["No local measurement was available from this WAV.", "The local specialist did not hear this waveform as a model or person."], runtimeMilliseconds: runtime,
            failure: failure, cancelled: cancelled
        )
    }

    private func elapsed(_ started: ContinuousClock.Instant) -> Int {
        let components = (ContinuousClock.now - started).components
        return max(0, Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000))
    }

    private func analysisClass(_ source: SourceType) -> SourceAnalysisClass {
        switch source {
        case .vocal, .vocalBus: .vocal
        case .drums, .drumBus: .drums
        case .bass: .bass
        case .guitar: .guitar
        case .keyboard, .synth: .synthKeys
        case .fullMix, .reference, .unknown: .fullStereoMix
        }
    }
}

public struct TutorComparisonAuthority: Codable, Equatable, Sendable {
    public var baseline: TutorAudioCaptureIdentity
    /// Persisted descriptive measurements are required to compute a comparison;
    /// identity continuity alone never authorizes a before/after claim.
    public var baselineMetrics: [TutorMetricEvidence]?
    public var expectedSignalPathRelation: String

    public init(baseline: TutorCaptureSnapshot, expectedSignalPathRelation: String = "A later capture must be from the same TrackSmith instance, runtime, labeled source, and measurement scope after the user-performed edit.") {
        self.baseline = TutorAudioCaptureIdentity(baseline)
        self.baselineMetrics = baseline.metrics.isEmpty ? nil : baseline.metrics
        self.expectedSignalPathRelation = expectedSignalPathRelation
    }
}

public struct TutorMeasurementDelta: Codable, Equatable, Sendable, Identifiable {
    public var id: String { identifier }
    public var identifier: String
    public var before: Double
    public var after: Double
    public var delta: Double
    public var unit: String
    public var interpretationBoundary: String

    public init(identifier: String, before: Double, after: Double, unit: String, interpretationBoundary: String) {
        self.identifier = identifier
        self.before = before
        self.after = after
        delta = after - before
        self.unit = unit
        self.interpretationBoundary = interpretationBoundary
    }
}

public struct TutorWaveformComparison: Codable, Equatable, Sendable {
    public var available: Bool
    public var reason: String
    public var baselineSHA256: String
    public var followUpSHA256: String?
    public var measurementDeltas: [TutorMeasurementDelta]?

    public init(available: Bool, reason: String, baselineSHA256: String, followUpSHA256: String? = nil, measurementDeltas: [TutorMeasurementDelta]? = nil) {
        self.available = available
        self.reason = reason
        self.baselineSHA256 = baselineSHA256
        self.followUpSHA256 = followUpSHA256
        self.measurementDeltas = measurementDeltas
    }
}

public enum TutorComparisonAuthorityValidator {
    public static func validate(authority: TutorComparisonAuthority?, followUp: TutorCaptureSnapshot?, userConfirmedUpstreamAndObservable: Bool) -> TutorWaveformComparison {
        guard let authority else { return .init(available: false, reason: "No baseline capture authority was attached to this experiment.", baselineSHA256: "") }
        guard let followUp else { return .init(available: false, reason: "No later exact capture was supplied; only the user-reported outcome is retained.", baselineSHA256: authority.baseline.sha256) }
        guard userConfirmedUpstreamAndObservable else { return .init(available: false, reason: "The user did not confirm the edit was upstream of and observable at the TrackSmith measurement tap.", baselineSHA256: authority.baseline.sha256, followUpSHA256: followUp.sha256) }
        guard followUp.captureSnapshotID != authority.baseline.captureSnapshotID,
              followUp.sha256 != authority.baseline.sha256,
              followUp.capturedAt > authority.baseline.capturedAt else { return .init(available: false, reason: "The follow-up must be a distinct later capture; a hash difference alone is not comparison authority.", baselineSHA256: authority.baseline.sha256, followUpSHA256: followUp.sha256) }
        guard let baselineFormat = authority.baseline.formatDescription,
              let followUpFormat = followUp.formatDescription,
              followUp.instanceID == authority.baseline.instanceID,
              followUp.runtimeEpoch == authority.baseline.runtimeEpoch,
              followUp.sourceType == authority.baseline.sourceType,
              followUp.scopeDescription == authority.baseline.scopeDescription,
              followUpFormat == baselineFormat else { return .init(available: false, reason: "The follow-up did not preserve the authorized instance, runtime, source, scope, and format.", baselineSHA256: authority.baseline.sha256, followUpSHA256: followUp.sha256) }
        guard let baselineMetrics = authority.baselineMetrics, !baselineMetrics.isEmpty else {
            return .init(available: false, reason: "The baseline has no persisted local measurements, so only the user-reported outcome is retained.", baselineSHA256: authority.baseline.sha256, followUpSHA256: followUp.sha256)
        }
        let afterByIdentifier = Dictionary(uniqueKeysWithValues: followUp.metrics.map { ($0.identifier, $0) })
        let deltas = baselineMetrics.compactMap { before -> TutorMeasurementDelta? in
            guard let after = afterByIdentifier[before.identifier], after.unit == before.unit else { return nil }
            return TutorMeasurementDelta(identifier: before.identifier, before: before.value, after: after.value, unit: before.unit, interpretationBoundary: before.interpretationBoundary)
        }.prefix(12)
        guard !deltas.isEmpty else {
            return .init(available: false, reason: "The compatible follow-up has no matching local measurement set, so no deterministic delta is available.", baselineSHA256: authority.baseline.sha256, followUpSHA256: followUp.sha256)
        }
        return .init(available: true, reason: "Authorized local measurement deltas are available for this bounded TrackSmith tap only; they are not hearing, causal masking, or subjective improvement.", baselineSHA256: authority.baseline.sha256, followUpSHA256: followUp.sha256, measurementDeltas: Array(deltas))
    }
}
