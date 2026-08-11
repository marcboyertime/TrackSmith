import AudioAnalysis
import Foundation
import PlanSchema
import ProductionIntelligence

public enum TutorMessageRole: String, Codable, CaseIterable, Sendable {
    case user
    case assistant
}

public enum TutorMessageStatus: String, Codable, CaseIterable, Sendable {
    case complete
    case cancelled
    case failed
}

public enum TutorEvidenceKind: String, Codable, CaseIterable, Sendable {
    case heardByModel
    case locallyMeasured
    case logicObserved
    case userReported
    case reviewedKnowledge
    case separatedSourceEstimate
    case structureEstimate
    case inference
    case unavailable

    public var compactLabel: String {
        switch self {
        case .heardByModel: "Heard"
        case .locallyMeasured: "Measured"
        case .logicObserved: "Saw"
        case .userReported: "You told me"
        case .reviewedKnowledge: "Reviewed"
        case .separatedSourceEstimate: "Separated estimate"
        case .structureEstimate: "Structure estimate"
        case .inference: "Inference"
        case .unavailable: "Unavailable"
        }
    }
}

public struct TutorEvidenceReference: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: TutorEvidenceKind
    public var label: String
    public var detail: String
    public var confidence: Double?
    public var captureSnapshotID: UUID?
    public var metricIdentifier: String?

    public init(
        id: UUID = UUID(),
        kind: TutorEvidenceKind,
        label: String,
        detail: String,
        confidence: Double? = nil,
        captureSnapshotID: UUID? = nil,
        metricIdentifier: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.detail = detail
        self.confidence = confidence.map { min(max($0.isFinite ? $0 : 0, 0), 1) }
        self.captureSnapshotID = captureSnapshotID
        self.metricIdentifier = metricIdentifier
    }
}

public struct TutorConversationMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var role: TutorMessageRole
    public var text: String
    public var createdAt: Date
    public var status: TutorMessageStatus
    public var evidence: [TutorEvidenceReference]
    public var experimentID: UUID?

    public init(
        id: UUID = UUID(),
        role: TutorMessageRole,
        text: String,
        createdAt: Date = Date(),
        status: TutorMessageStatus = .complete,
        evidence: [TutorEvidenceReference] = [],
        experimentID: UUID? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
        self.status = status
        self.evidence = evidence
        self.experimentID = experimentID
    }
}

public struct TutorMetricEvidence: Codable, Equatable, Sendable {
    public var identifier: String
    public var value: Double
    public var unit: String
    public var confidence: Double
    public var interpretationBoundary: String

    public init(
        identifier: String,
        value: Double,
        unit: String,
        confidence: Double,
        interpretationBoundary: String
    ) {
        self.identifier = identifier
        self.value = value.isFinite ? value : 0
        self.unit = unit
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
        self.interpretationBoundary = interpretationBoundary
    }
}

public enum TutorCloudListeningStatus: String, Codable, CaseIterable, Sendable {
    case notRequested
    case consentDenied
    case unavailable
    case listened
}

public struct TutorCloudListeningEvidence: Codable, Equatable, Sendable {
    public var status: TutorCloudListeningStatus
    public var summary: String?
    public var providerIdentifier: String?
    public var modelIdentifier: String?
    public var captureSnapshotID: UUID?

    public init(
        status: TutorCloudListeningStatus,
        summary: String? = nil,
        providerIdentifier: String? = nil,
        modelIdentifier: String? = nil,
        captureSnapshotID: UUID? = nil
    ) {
        self.status = status
        self.summary = summary
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.captureSnapshotID = captureSnapshotID
    }
}

public struct TutorCaptureSnapshot: Codable, Equatable, Sendable {
    public var sourceType: SourceType
    public var instanceID: UUID
    public var runtimeEpoch: UUID
    public var captureSnapshotID: UUID
    public var sha256: String
    public var capturedAt: Date
    public var durationSeconds: Double
    public var scopeDescription: String
    /// Additive format label (for example "48000 Hz stereo Float32 WAV").
    public var formatDescription: String?
    public var isLive: Bool
    public var metrics: [TutorMetricEvidence]
    public var localAnalysisLimitations: [String]
    public var cloudListening: TutorCloudListeningEvidence
    /// Optional so records written before the local waveform specialist remain decodable.
    public var audioIntelligence: TutorAudioIntelligenceResult?

    public init(
        sourceType: SourceType,
        instanceID: UUID,
        runtimeEpoch: UUID,
        captureSnapshotID: UUID,
        sha256: String,
        capturedAt: Date,
        durationSeconds: Double,
        scopeDescription: String,
        formatDescription: String? = nil,
        isLive: Bool,
        metrics: [TutorMetricEvidence],
        localAnalysisLimitations: [String],
        cloudListening: TutorCloudListeningEvidence = .init(status: .notRequested),
        audioIntelligence: TutorAudioIntelligenceResult? = nil
    ) {
        self.sourceType = sourceType
        self.instanceID = instanceID
        self.runtimeEpoch = runtimeEpoch
        self.captureSnapshotID = captureSnapshotID
        self.sha256 = sha256
        self.capturedAt = capturedAt
        self.durationSeconds = durationSeconds.isFinite ? min(max(durationSeconds, 0), 30) : 0
        self.scopeDescription = scopeDescription
        self.formatDescription = formatDescription
        self.isLive = isLive
        self.metrics = Array(metrics.prefix(16))
        self.localAnalysisLimitations = Array(localAnalysisLimitations.prefix(8))
        self.cloudListening = cloudListening
        self.audioIntelligence = audioIntelligence
    }
}

public struct TutorScreenRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct TutorObservedControl: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var role: String
    public var label: String
    public var value: String?
    public var frame: TutorScreenRect?

    public init(
        id: UUID = UUID(),
        role: String,
        label: String,
        value: String? = nil,
        frame: TutorScreenRect? = nil
    ) {
        self.id = id
        self.role = role
        self.label = label
        self.value = value
        self.frame = frame
    }
}

public enum TutorLogicObservationStatus: String, Codable, CaseIterable, Sendable {
    case observed
    case logicNotRunning
    case permissionDenied
    case controlNotFound
    case unavailable
}

public struct TutorLogicObservation: Codable, Equatable, Sendable {
    public var status: TutorLogicObservationStatus
    public var applicationName: String?
    public var bundleIdentifier: String?
    public var windowTitle: String?
    public var controls: [TutorObservedControl]
    public var limitation: String
    public var observedAt: Date

    public init(
        status: TutorLogicObservationStatus,
        applicationName: String? = nil,
        bundleIdentifier: String? = nil,
        windowTitle: String? = nil,
        controls: [TutorObservedControl] = [],
        limitation: String,
        observedAt: Date = Date()
    ) {
        self.status = status
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.controls = Array(controls.prefix(40))
        self.limitation = limitation
        self.observedAt = observedAt
    }

    public static let unavailable = TutorLogicObservation(
        status: .unavailable,
        limitation: "Logic observation was not requested or is unavailable."
    )
}

public struct TutorRuntimeContext: Codable, Equatable, Sendable {
    public var sourceType: SourceType
    public var projectGoal: String?
    public var capture: TutorCaptureSnapshot?
    public var logicObservation: TutorLogicObservation?
    public var userReportedContext: [String]
    public var consent: TutorConsentContext

    public init(
        sourceType: SourceType,
        projectGoal: String? = nil,
        capture: TutorCaptureSnapshot? = nil,
        logicObservation: TutorLogicObservation? = nil,
        userReportedContext: [String] = [],
        consent: TutorConsentContext = .init()
    ) {
        self.sourceType = sourceType
        self.projectGoal = projectGoal
        self.capture = capture
        self.logicObservation = logicObservation
        self.userReportedContext = Array(userReportedContext.prefix(12))
        self.consent = consent
    }
}

public struct TutorConsentContext: Codable, Equatable, Sendable {
    public var cloudTextGranted: Bool
    public var cloudAudioGranted: Bool
    public var audioRequested: Bool

    public init(
        cloudTextGranted: Bool = false,
        cloudAudioGranted: Bool = false,
        audioRequested: Bool = false
    ) {
        self.cloudTextGranted = cloudTextGranted
        self.cloudAudioGranted = cloudAudioGranted
        self.audioRequested = audioRequested
    }
}

public struct TutorExperimentDraft: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var logicLocation: String
    public var action: String
    public var startingRange: String
    public var listenFor: String
    public var why: String
    public var risk: String
    public var undo: String
    public var visualTargetQuery: String?

    public init(
        id: UUID = UUID(),
        title: String,
        logicLocation: String,
        action: String,
        startingRange: String,
        listenFor: String,
        why: String,
        risk: String,
        undo: String,
        visualTargetQuery: String? = nil
    ) {
        self.id = id
        self.title = title
        self.logicLocation = logicLocation
        self.action = action
        self.startingRange = startingRange
        self.listenFor = listenFor
        self.why = why
        self.risk = risk
        self.undo = undo
        self.visualTargetQuery = visualTargetQuery
    }
}

public enum TutorExperimentOutcome: String, Codable, CaseIterable, Sendable {
    case better
    case worse
    case noChange
    case cannotFind
    case notSure
}

public struct TutorExperimentRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { draft.id }
    public var draft: TutorExperimentDraft
    public var createdAt: Date
    public var outcome: TutorExperimentOutcome?
    public var userNote: String?
    public var userReportedSettings: [String]
    public var evidenceReceiptID: UUID?
    /// Optional additive Phase 2 fields preserve older persisted records.
    public var comparisonAuthority: TutorComparisonAuthority?
    public var waveformComparison: TutorWaveformComparison?

    public init(
        draft: TutorExperimentDraft,
        createdAt: Date = Date(),
        outcome: TutorExperimentOutcome? = nil,
        userNote: String? = nil,
        userReportedSettings: [String] = [],
        evidenceReceiptID: UUID? = nil,
        comparisonAuthority: TutorComparisonAuthority? = nil,
        waveformComparison: TutorWaveformComparison? = nil
    ) {
        self.draft = draft
        self.createdAt = createdAt
        self.outcome = outcome
        self.userNote = userNote
        self.userReportedSettings = Array(userReportedSettings.prefix(12))
        self.evidenceReceiptID = evidenceReceiptID
        self.comparisonAuthority = comparisonAuthority
        self.waveformComparison = waveformComparison
    }
}

public struct TutorConversationState: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var version: String
    public var createdAt: Date
    public var updatedAt: Date
    public var projectGoal: String?
    public var messages: [TutorConversationMessage]
    public var experiments: [TutorExperimentRecord]

    public init(
        id: UUID = UUID(),
        version: String = "1.0",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projectGoal: String? = nil,
        messages: [TutorConversationMessage] = [],
        experiments: [TutorExperimentRecord] = []
    ) {
        self.id = id
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectGoal = projectGoal
        self.messages = messages
        self.experiments = experiments
    }
}

public enum TutorReasoningEffort: String, Codable, CaseIterable, Sendable {
    case none, low, medium, high, xhigh, max
}

public struct TutorProviderConfiguration: Codable, Equatable, Sendable {
    public var modelIdentifier: String
    public var reasoningEffort: TutorReasoningEffort
    public var cloudTextConsent: Bool
    public var timeoutSeconds: Double
    public var maximumOutputTokens: Int

    public init(
        modelIdentifier: String = "gpt-5.6-sol",
        reasoningEffort: TutorReasoningEffort = .high,
        cloudTextConsent: Bool = false,
        timeoutSeconds: Double = 45,
        maximumOutputTokens: Int = 25_000
    ) {
        self.modelIdentifier = modelIdentifier
        self.reasoningEffort = reasoningEffort
        self.cloudTextConsent = cloudTextConsent
        self.timeoutSeconds = min(max(timeoutSeconds, 1), 60)
        self.maximumOutputTokens = min(max(maximumOutputTokens, 256), 32_768)
    }
}

public struct TutorProviderMetadata: Codable, Equatable, Sendable {
    public var providerIdentifier: String
    public var modelIdentifier: String
    public var providerResponseID: String?
    public var inputTokens: Int?
    public var outputTokens: Int?

    public init(
        providerIdentifier: String,
        modelIdentifier: String,
        providerResponseID: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.providerIdentifier = providerIdentifier
        self.modelIdentifier = modelIdentifier
        self.providerResponseID = providerResponseID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public struct TutorToolDefinition: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case readOnly, presentationOnly }
    public var name: String
    public var description: String
    public var kind: Kind

    public init(name: String, description: String, kind: Kind) {
        self.name = name
        self.description = description
        self.kind = kind
    }
}

public struct TutorToolCall: Codable, Equatable, Identifiable, Sendable {
    public var id: String { callID }
    public var callID: String
    public var name: String
    public var argumentsJSON: String

    public init(callID: String, name: String, argumentsJSON: String) {
        self.callID = callID
        self.name = name
        self.argumentsJSON = argumentsJSON
    }
}

public struct TutorToolResult: Codable, Equatable, Sendable {
    public var call: TutorToolCall
    public var outputJSON: String
    public var evidence: [TutorEvidenceReference]
    public var experiment: TutorExperimentDraft?

    public init(
        call: TutorToolCall,
        outputJSON: String,
        evidence: [TutorEvidenceReference] = [],
        experiment: TutorExperimentDraft? = nil
    ) {
        self.call = call
        self.outputJSON = outputJSON
        self.evidence = evidence
        self.experiment = experiment
    }
}

public struct TutorProviderContinuation: Codable, Equatable, Sendable {
    public var call: TutorToolCall
    public var outputJSON: String

    public init(call: TutorToolCall, outputJSON: String) {
        self.call = call
        self.outputJSON = outputJSON
    }
}

public struct TutorProviderRequest: Equatable, Sendable {
    public var messages: [TutorConversationMessage]
    public var context: TutorRuntimeContext
    public var tools: [TutorToolDefinition]
    public var continuations: [TutorProviderContinuation]
    /// Ordered, provider-native output items plus function outputs retained
    /// only for the current tool loop. These are never persisted as Tutor state.
    public var responseInputItemsJSON: [String]

    public init(
        messages: [TutorConversationMessage],
        context: TutorRuntimeContext,
        tools: [TutorToolDefinition],
        continuations: [TutorProviderContinuation] = [],
        responseInputItemsJSON: [String] = []
    ) {
        self.messages = messages
        self.context = context
        self.tools = tools
        self.continuations = continuations
        self.responseInputItemsJSON = responseInputItemsJSON
    }
}

public enum TutorProviderOutputItem: Equatable, Sendable {
    case text(String)
    case functionCall(TutorToolCall)
    /// A bounded Responses API output item suitable for stateless replay.
    /// It can contain encrypted reasoning continuity, never raw chain of thought.
    case responseInputItemJSON(String)
}

public enum TutorProviderEvent: Equatable, Sendable {
    case textDelta(String)
    case completed(metadata: TutorProviderMetadata, output: [TutorProviderOutputItem])
}

public protocol TutorConversationProvider: Sendable {
    var providerIdentifier: String { get }
    func stream(_ request: TutorProviderRequest) -> AsyncThrowingStream<TutorProviderEvent, Error>
}

public struct TutorToolReceipt: Codable, Equatable, Sendable {
    public var name: String
    public var callID: String
    public var argumentsSHA256: String
    public var outputSHA256: String

    public init(name: String, callID: String, argumentsSHA256: String, outputSHA256: String) {
        self.name = name
        self.callID = callID
        self.argumentsSHA256 = argumentsSHA256
        self.outputSHA256 = outputSHA256
    }
}

public enum TutorConsentModality: String, Codable, CaseIterable, Sendable {
    case cloudConversationText
    case cloudCaptureAudio
    case readOnlyLogicAccessibility
}

public struct TutorConsentReceipt: Codable, Equatable, Sendable {
    public var modality: TutorConsentModality
    public var granted: Bool
    public var purpose: String
    public var captureSnapshotID: UUID?

    public init(
        modality: TutorConsentModality,
        granted: Bool,
        purpose: String,
        captureSnapshotID: UUID? = nil
    ) {
        self.modality = modality
        self.granted = granted
        self.purpose = purpose
        self.captureSnapshotID = captureSnapshotID
    }
}

public struct TutorEvidenceReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var version: String
    public var conversationID: UUID
    public var userMessageID: UUID
    public var assistantMessageID: UUID
    public var createdAt: Date
    public var provider: TutorProviderMetadata
    /// Present only when a primary provider failed and the completed answer
    /// came from the deterministic fallback. This is a bounded, redacted
    /// operational summary, never a raw response body or credential value.
    public var fallbackReason: String?
    public var assistantTextSHA256: String
    public var captureSnapshotID: UUID?
    public var captureSHA256: String?
    public var evidence: [TutorEvidenceReference]
    public var tools: [TutorToolReceipt]
    public var consents: [TutorConsentReceipt]

    public init(
        id: UUID = UUID(),
        version: String = "1.0",
        conversationID: UUID,
        userMessageID: UUID,
        assistantMessageID: UUID,
        createdAt: Date = Date(),
        provider: TutorProviderMetadata,
        fallbackReason: String? = nil,
        assistantTextSHA256: String,
        captureSnapshotID: UUID?,
        captureSHA256: String?,
        evidence: [TutorEvidenceReference],
        tools: [TutorToolReceipt],
        consents: [TutorConsentReceipt] = []
    ) {
        self.id = id
        self.version = version
        self.conversationID = conversationID
        self.userMessageID = userMessageID
        self.assistantMessageID = assistantMessageID
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
        self.provider = provider
        self.fallbackReason = fallbackReason
        self.assistantTextSHA256 = assistantTextSHA256
        self.captureSnapshotID = captureSnapshotID
        self.captureSHA256 = captureSHA256
        self.evidence = evidence
        self.tools = tools
        self.consents = consents
    }
}

public enum TutorConversationEvent: Sendable {
    case textDelta(messageID: UUID, text: String)
    case toolActivity(String)
    case experiment(TutorExperimentRecord)
    case fallbackActivated(String)
    case completed(message: TutorConversationMessage, receipt: TutorEvidenceReceipt)
    case cancelled(messageID: UUID)
}

public enum TutorConversationError: Error, Equatable, Sendable {
    case emptyMessage
    case turnInProgress
    case messageTooLarge
    case consentRequired
    case credentialMissing
    case credentialUnavailable
    case invalidModel
    case providerRejected(String)
    case malformedProviderResponse(String)
    case responseTooLarge
    case timedOut
    case cancelled
    case toolLimitReached
    case unknownTool(String)
    case invalidToolArguments(String)
    case persistence(String)
    case audioConsentRequired
    case audioAttachmentTooLarge
    case staleCapture
}

public extension TutorConversationError {
    /// A user/receipt-safe reason that deliberately excludes response bodies,
    /// paths, request contents, and credentials. Provider details are reduced
    /// to an HTTP status or a fixed category.
    var safeFailureDescription: String {
        switch self {
        case .emptyMessage:
            "The request was empty."
        case .turnInProgress:
            "Another Tutor turn is already running."
        case .messageTooLarge:
            "The request exceeded the bounded message limit."
        case .consentRequired:
            "Cloud conversation consent is off."
        case .credentialMissing:
            "No OpenAI credential is available."
        case .credentialUnavailable:
            "The local credential store was unavailable."
        case .invalidModel:
            "The configured model identifier is invalid."
        case let .providerRejected(detail):
            Self.safeProviderRejection(detail)
        case .malformedProviderResponse:
            "The provider returned no usable bounded response."
        case .responseTooLarge:
            "The provider response exceeded a TrackSmith size limit."
        case .timedOut:
            "The provider request timed out."
        case .cancelled:
            "The request was cancelled."
        case .toolLimitReached:
            "The bounded tool-call limit was reached."
        case .unknownTool:
            "The provider requested a tool outside TrackSmith's allowlist."
        case .invalidToolArguments:
            "The provider supplied invalid bounded tool arguments."
        case .persistence:
            "Local Tutor persistence was unavailable."
        case .audioConsentRequired:
            "Separate cloud-audio consent is off."
        case .audioAttachmentTooLarge:
            "The audio attachment exceeded the bounded upload limit."
        case .staleCapture:
            "The selected capture no longer matched its immutable snapshot."
        }
    }

    private static func safeProviderRejection(_ detail: String) -> String {
        let lowercased = detail.lowercased()
        if lowercased.contains("credential") {
            return "The provider rejected the OpenAI credential."
        }
        for token in detail.split(whereSeparator: { !$0.isNumber }) {
            if token.count == 3, let status = Int(token), (100...599).contains(status) {
                return "The provider returned HTTP \(status)."
            }
        }
        return "The provider rejected the request."
    }
}
