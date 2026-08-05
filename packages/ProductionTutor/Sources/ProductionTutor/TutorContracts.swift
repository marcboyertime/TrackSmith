import Foundation
import PlanSchema

// MARK: - Request classification

public enum TutorRequestKind: String, Codable, CaseIterable, Sendable {
    case troubleshootProblem
    case achieveSound
    case explainConcept
    case workflowHelp
}

/// Whether the current guidance is grounded in a recent local capture or only
/// in what the user reported. The UI must keep this distinction visible.
public enum TutorEvidenceMode: String, Codable, CaseIterable, Sendable {
    case audioGrounded
    case userReportedOnly
}

public enum TutorExplanationDepth: String, Codable, CaseIterable, Sendable {
    case simple
    case standard
    case technical
}

// MARK: - Evidence

public enum TutorEvidenceProvenanceClass: String, Codable, CaseIterable, Sendable {
    case userReported
    case locallyMeasured
    case appleDocumentedBehavior
    case directLogicEmpiricalEvidence
    case peerReviewedResearch
    case professionalPracticeHeuristic
    case trackSmithProductHeuristic
    case userConfirmedExperimentOutcome
}

public enum TutorEvidenceRelationship: String, Codable, CaseIterable, Sendable {
    case supports
    case contradicts
    case doesNotResolve
    case unavailable
}

/// One diagnosis-relevant statement with explicit provenance and relationship.
/// This is structured evidence for display, never hidden chain of thought.
public struct TutorEvidenceStatement: Codable, Equatable, Sendable {
    public var statement: String
    public var provenanceClass: TutorEvidenceProvenanceClass
    public var relationship: TutorEvidenceRelationship
    public var metricIdentifier: String?
    public var value: Double?
    public var unit: String?
    public var confidence: Double

    public init(
        statement: String,
        provenanceClass: TutorEvidenceProvenanceClass,
        relationship: TutorEvidenceRelationship,
        metricIdentifier: String? = nil,
        value: Double? = nil,
        unit: String? = nil,
        confidence: Double
    ) {
        self.statement = statement
        self.provenanceClass = provenanceClass
        self.relationship = relationship
        self.metricIdentifier = metricIdentifier
        self.value = value.map { $0.isFinite ? $0 : 0 }
        self.unit = unit
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
    }
}

// MARK: - Actors and actions

/// Who performs a step. Tutor v1 deliberately has no "TrackSmith controls
/// Logic" actor; TrackSmith never operates the host.
public enum TutorActor: String, Codable, CaseIterable, Sendable {
    case userManual
    case trackSmithReadOnlyAnalysis
    case trackSmithPreviewDemonstration
}

public enum TutorActionKind: String, Codable, CaseIterable, Sendable {
    case askClarifyingQuestion
    case inspectOrConfirmCurrentState
    case bypassProcessor
    case enableProcessor
    case openNativeProcessor
    case setControl
    case sweepControl
    case compareBypass
    case levelMatchComparison
    case recordAlternateTake
    case changeMicrophonePosition
    case adjustPerformanceApproach
    case restorePreviousState
    case reportObservation
    case stopAndPreserve
    case reportLimitation
}

public enum TutorFeedback: String, Codable, CaseIterable, Sendable {
    case better
    case worse
    case noChange
    case notSure
    case notApplicable
    case cannotFindControl
    case done
    case undo
}

// MARK: - Teaching concepts

public enum TutorConceptID: String, Codable, CaseIterable, Sendable {
    case levelMatchedComparison
    case resonance
    case frequency
    case gain
    case qBandwidth
    case highPassFilter
    case threshold
    case ratio
    case attack
    case release
    case makeupGain
    case dynamicVersusStaticProcessing
    case sibilance
    case wetDry
    case preDelay
    case feedback
    case gainStaging
    case sourceVersusProcessing
    case monitoringBias
}

// MARK: - User-reported processing chain

public enum TutorReportedProcessor: String, Codable, CaseIterable, Sendable {
    case eq
    case compressor
    case deEsser
    case gateOrExpander
    case pitchProcessor
    case reverb
    case delay
}

/// What the user says is on the Logic channel strip. TrackSmith cannot inspect
/// arbitrary Logic inserts, so this is always labeled user-reported.
public struct TutorUserReportedChain: Codable, Equatable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case unknown
        case none
        case reported
    }

    public var status: Status
    public var processors: [TutorReportedProcessor]

    public init(status: Status = .unknown, processors: [TutorReportedProcessor] = []) {
        self.status = status
        self.processors = status == .reported ? processors : []
    }

    public static let unknown = TutorUserReportedChain(status: .unknown)
    public static let none = TutorUserReportedChain(status: .none)

    public func reports(_ processor: TutorReportedProcessor) -> Bool {
        status == .reported && processors.contains(processor)
    }

    /// True when the chain might contain the processor: the user either
    /// reported it or has not described the chain at all.
    public func mayContain(_ processor: TutorReportedProcessor) -> Bool {
        switch status {
        case .unknown: true
        case .none: false
        case .reported: processors.contains(processor)
        }
    }
}

// MARK: - Logic locations, controls, and values

public enum TutorUIVerificationStatus: String, Codable, CaseIterable, Sendable {
    case documentary
    case directlyVerified
    case documentaryAndDirectlyVerified
}

/// A versioned semantic UI target. Pixel coordinates are prohibited and the
/// knowledge validator rejects coordinate-like content.
public struct TutorLogicLocation: Codable, Equatable, Sendable {
    public var logicVersion: String
    public var workArea: String
    public var objectScope: String
    public var processorIdentity: String?
    public var controlIdentity: String?
    public var navigationLabels: [String]
    public var requiredFocusOrSelection: String
    public var prerequisites: [String]
    public var verification: TutorUIVerificationStatus
    public var sourceReferences: [String]
    public var lastDirectlyVerified: String?

    public init(
        logicVersion: String,
        workArea: String,
        objectScope: String,
        processorIdentity: String? = nil,
        controlIdentity: String? = nil,
        navigationLabels: [String],
        requiredFocusOrSelection: String,
        prerequisites: [String] = [],
        verification: TutorUIVerificationStatus,
        sourceReferences: [String],
        lastDirectlyVerified: String? = nil
    ) {
        self.logicVersion = logicVersion
        self.workArea = workArea
        self.objectScope = objectScope
        self.processorIdentity = processorIdentity
        self.controlIdentity = controlIdentity
        self.navigationLabels = navigationLabels
        self.requiredFocusOrSelection = requiredFocusOrSelection
        self.prerequisites = prerequisites
        self.verification = verification
        self.sourceReferences = sourceReferences
        self.lastDirectlyVerified = lastDirectlyVerified
    }
}

public enum TutorParameterUnit: String, Codable, CaseIterable, Sendable {
    case boolean
    case enumeration
    case decibels
    case hertz
    case milliseconds
    case seconds
    case ratio
    case q
    case percent
    case noteValue
    case textObservation
}

public enum TutorAdjustmentMethod: String, Codable, CaseIterable, Sendable {
    case setExactValue
    case slowContinuousSweep
    case steppedAdjustment
    case toggle
    case chooseFromMenu
    case observeOnly
}

public enum TutorSweepDirection: String, Codable, CaseIterable, Sendable {
    case upward
    case downward
    case bothFromStart
    case notApplicable
}

/// A locally bounded numeric or enumerated instruction. Providers never author
/// these values; the knowledge validator enforces the bounds.
public struct TutorParameterInstruction: Codable, Equatable, Sendable {
    public var controlIdentity: String
    public var unit: TutorParameterUnit
    public var safeStartingValue: Double?
    public var minimumValue: Double?
    public var maximumValue: Double?
    public var enumeratedChoices: [String]
    public var adjustmentMethod: TutorAdjustmentMethod
    public var sweepDirection: TutorSweepDirection
    public var stepDescription: String?
    public var stopCondition: String
    public var maximumRecommendedExcursion: Double?
    public var audibleWarningSigns: [String]
    public var rollbackValueDescription: String

    public init(
        controlIdentity: String,
        unit: TutorParameterUnit,
        safeStartingValue: Double? = nil,
        minimumValue: Double? = nil,
        maximumValue: Double? = nil,
        enumeratedChoices: [String] = [],
        adjustmentMethod: TutorAdjustmentMethod,
        sweepDirection: TutorSweepDirection = .notApplicable,
        stepDescription: String? = nil,
        stopCondition: String,
        maximumRecommendedExcursion: Double? = nil,
        audibleWarningSigns: [String] = [],
        rollbackValueDescription: String
    ) {
        self.controlIdentity = controlIdentity
        self.unit = unit
        self.safeStartingValue = safeStartingValue
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.enumeratedChoices = enumeratedChoices
        self.adjustmentMethod = adjustmentMethod
        self.sweepDirection = sweepDirection
        self.stepDescription = stepDescription
        self.stopCondition = stopCondition
        self.maximumRecommendedExcursion = maximumRecommendedExcursion
        self.audibleWarningSigns = audibleWarningSigns
        self.rollbackValueDescription = rollbackValueDescription
    }
}

// MARK: - Steps

public struct TutorStepFeedbackBranch: Codable, Equatable, Sendable {
    public var feedback: TutorFeedback
    /// The catalog step to activate next, or nil when the deterministic
    /// reducer resolves the transition at the lesson level (procedure switch,
    /// completion, or limitation).
    public var nextStepID: String?
    public var effectSummary: String

    public init(feedback: TutorFeedback, nextStepID: String? = nil, effectSummary: String) {
        self.feedback = feedback
        self.nextStepID = nextStepID
        self.effectSummary = effectSummary
    }
}

public struct TutorStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var procedureID: String
    public var actionKind: TutorActionKind
    public var actor: TutorActor
    public var title: String
    public var instruction: String
    public var substeps: [String]
    public var reason: String
    public var technicalExplanation: String
    public var listenFor: String
    public var expectedResult: String
    public var hypothesisWrongSigns: [String]
    public var preservationChecks: [String]
    public var commonSideEffect: String
    public var stopCondition: String
    public var undoInstruction: String
    public var location: TutorLogicLocation?
    public var parameters: [TutorParameterInstruction]
    public var supportedFeedback: [TutorFeedback]
    public var branches: [TutorStepFeedbackBranch]
    public var confidence: Double
    public var uncertainty: [String]
    public var concepts: [TutorConceptID]

    public init(
        id: String,
        procedureID: String,
        actionKind: TutorActionKind,
        actor: TutorActor,
        title: String,
        instruction: String,
        substeps: [String] = [],
        reason: String,
        technicalExplanation: String,
        listenFor: String,
        expectedResult: String,
        hypothesisWrongSigns: [String] = [],
        preservationChecks: [String] = [],
        commonSideEffect: String,
        stopCondition: String,
        undoInstruction: String,
        location: TutorLogicLocation? = nil,
        parameters: [TutorParameterInstruction] = [],
        supportedFeedback: [TutorFeedback],
        branches: [TutorStepFeedbackBranch] = [],
        confidence: Double,
        uncertainty: [String] = [],
        concepts: [TutorConceptID] = []
    ) {
        self.id = id
        self.procedureID = procedureID
        self.actionKind = actionKind
        self.actor = actor
        self.title = title
        self.instruction = instruction
        self.substeps = substeps
        self.reason = reason
        self.technicalExplanation = technicalExplanation
        self.listenFor = listenFor
        self.expectedResult = expectedResult
        self.hypothesisWrongSigns = hypothesisWrongSigns
        self.preservationChecks = preservationChecks
        self.commonSideEffect = commonSideEffect
        self.stopCondition = stopCondition
        self.undoInstruction = undoInstruction
        self.location = location
        self.parameters = parameters
        self.supportedFeedback = supportedFeedback
        self.branches = branches
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
        self.uncertainty = uncertainty
        self.concepts = concepts
    }
}

// MARK: - Cause hypotheses

public enum TutorCauseCategory: String, Codable, CaseIterable, Sendable {
    case performanceOrVowelFormation
    case microphonePositionOrCapture
    case roomOrReflection
    case existingProcessing
    case staticSpectralResonance
    case timeVaryingResonance
    case dynamicsInteraction
    case ambienceInteraction
    case arrangementOrMasking
    case monitoringOrLevelBias
    case hostWorkflow
    case unknown
}

public enum TutorHypothesisStatus: String, Codable, CaseIterable, Sendable {
    case open
    case strengthened
    case weakened
    case contraindicated
}

public struct TutorCauseHypothesis: Codable, Equatable, Sendable {
    public var causeCategory: TutorCauseCategory
    public var summary: String
    public var evidence: [TutorEvidenceStatement]
    /// A bounded ordering weight for presentation. This is a product
    /// heuristic, never presented as an objective probability.
    public var plausibilityWeight: Double
    public var status: TutorHypothesisStatus

    public init(
        causeCategory: TutorCauseCategory,
        summary: String,
        evidence: [TutorEvidenceStatement] = [],
        plausibilityWeight: Double,
        status: TutorHypothesisStatus = .open
    ) {
        self.causeCategory = causeCategory
        self.summary = summary
        self.evidence = evidence
        self.plausibilityWeight = min(max(plausibilityWeight.isFinite ? plausibilityWeight : 0, 0), 1)
        self.status = status
    }
}

// MARK: - Lesson state

/// Safe authority references only: identities, never paths or audio.
public struct TutorAuthorityReference: Codable, Equatable, Sendable {
    public var instanceID: UUID?
    public var runtimeEpoch: UUID?
    public var captureSnapshotID: UUID?
    public var sourceType: SourceType

    public init(
        instanceID: UUID? = nil,
        runtimeEpoch: UUID? = nil,
        captureSnapshotID: UUID? = nil,
        sourceType: SourceType
    ) {
        self.instanceID = instanceID
        self.runtimeEpoch = runtimeEpoch
        self.captureSnapshotID = captureSnapshotID
        self.sourceType = sourceType
    }
}

public enum TutorLessonStatus: String, Codable, CaseIterable, Sendable {
    case awaitingClarification
    case activeStep
    case completed
    case stoppedPreserved
    case limitedNoSafeProcedure
    case abandoned
}

public struct TutorFeedbackEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var stepID: String?
    public var feedback: TutorFeedback
    public var recordedAt: Date

    public init(id: UUID = UUID(), stepID: String?, feedback: TutorFeedback, recordedAt: Date = Date()) {
        self.id = id
        self.stepID = stepID
        self.feedback = feedback
        self.recordedAt = recordedAt
    }
}

public struct TutorLessonSummary: Codable, Equatable, Sendable {
    public var whatChanged: String
    public var likelyCause: String
    public var whatDidNotHelp: [String]
    public var whatWasPreserved: [String]
    public var principleToRemember: String
    /// Exact settings the user reported choosing, clearly labeled user-entered.
    public var userEnteredSettings: [String]
    public var remainingUncertainty: [String]

    public init(
        whatChanged: String,
        likelyCause: String,
        whatDidNotHelp: [String],
        whatWasPreserved: [String],
        principleToRemember: String,
        userEnteredSettings: [String],
        remainingUncertainty: [String]
    ) {
        self.whatChanged = whatChanged
        self.likelyCause = likelyCause
        self.whatDidNotHelp = whatDidNotHelp
        self.whatWasPreserved = whatWasPreserved
        self.principleToRemember = principleToRemember
        self.userEnteredSettings = userEnteredSettings
        self.remainingUncertainty = remainingUncertainty
    }
}

public struct TutorLessonState: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var version: String
    public var createdAt: Date
    public var updatedAt: Date
    public var requestKind: TutorRequestKind
    public var requestText: String
    public var sourceType: SourceType
    public var evidenceMode: TutorEvidenceMode
    public var authority: TutorAuthorityReference?
    /// True once the originating capture/AU authority no longer matches the
    /// live session; audio-grounded claims become historical, not live.
    public var audioEvidenceIsHistorical: Bool
    public var reportedIssues: [TutorIssueKind]
    public var hypotheses: [TutorCauseHypothesis]
    public var contextEvidence: [TutorEvidenceStatement]
    public var selectedProcedureID: String?
    public var steps: [TutorStep]
    public var activeStepID: String?
    public var completedStepIDs: [String]
    public var skippedStepIDs: [String]
    public var contraindicatedProcedureIDs: [String]
    public var attemptedProcedureIDs: [String]
    public var feedbackEvents: [TutorFeedbackEvent]
    public var userReportedChain: TutorUserReportedChain
    public var status: TutorLessonStatus
    public var clarificationQuestion: String?
    public var statusNote: String
    public var conceptsPracticed: [TutorConceptID]
    public var finalSummary: TutorLessonSummary?
    public var unresolvedLimitations: [String]

    public init(
        id: UUID = UUID(),
        version: String = "1.0",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        requestKind: TutorRequestKind,
        requestText: String,
        sourceType: SourceType,
        evidenceMode: TutorEvidenceMode,
        authority: TutorAuthorityReference? = nil,
        audioEvidenceIsHistorical: Bool = false,
        reportedIssues: [TutorIssueKind] = [],
        hypotheses: [TutorCauseHypothesis] = [],
        contextEvidence: [TutorEvidenceStatement] = [],
        selectedProcedureID: String? = nil,
        steps: [TutorStep] = [],
        activeStepID: String? = nil,
        completedStepIDs: [String] = [],
        skippedStepIDs: [String] = [],
        contraindicatedProcedureIDs: [String] = [],
        attemptedProcedureIDs: [String] = [],
        feedbackEvents: [TutorFeedbackEvent] = [],
        userReportedChain: TutorUserReportedChain = .unknown,
        status: TutorLessonStatus,
        clarificationQuestion: String? = nil,
        statusNote: String = "",
        conceptsPracticed: [TutorConceptID] = [],
        finalSummary: TutorLessonSummary? = nil,
        unresolvedLimitations: [String] = []
    ) {
        self.id = id
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.requestKind = requestKind
        self.requestText = requestText
        self.sourceType = sourceType
        self.evidenceMode = evidenceMode
        self.authority = authority
        self.audioEvidenceIsHistorical = audioEvidenceIsHistorical
        self.reportedIssues = reportedIssues
        self.hypotheses = hypotheses
        self.contextEvidence = contextEvidence
        self.selectedProcedureID = selectedProcedureID
        self.steps = steps
        self.activeStepID = activeStepID
        self.completedStepIDs = completedStepIDs
        self.skippedStepIDs = skippedStepIDs
        self.contraindicatedProcedureIDs = contraindicatedProcedureIDs
        self.attemptedProcedureIDs = attemptedProcedureIDs
        self.feedbackEvents = feedbackEvents
        self.userReportedChain = userReportedChain
        self.status = status
        self.clarificationQuestion = clarificationQuestion
        self.statusNote = statusNote
        self.conceptsPracticed = conceptsPracticed
        self.finalSummary = finalSummary
        self.unresolvedLimitations = unresolvedLimitations
    }

    public var activeStep: TutorStep? {
        guard let activeStepID else { return nil }
        return steps.first { $0.id == activeStepID }
    }
}
