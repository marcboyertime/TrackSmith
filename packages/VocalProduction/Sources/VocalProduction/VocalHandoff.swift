import DSPCore
import Foundation
import PlanSchema

public struct VocalHandoffMeasurement: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var metricIdentifier: String
    public var value: Double
    public var unit: String
    public var confidence: Double
    public var analysisVersion: String
    public var limitation: String

    public init(
        version: VocalSchemaVersion = .v1,
        metricIdentifier: String,
        value: Double,
        unit: String,
        confidence: Double,
        analysisVersion: String,
        limitation: String
    ) {
        self.version = version
        self.metricIdentifier = metricIdentifier
        self.value = value.isFinite ? value : 0
        self.unit = unit
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
        self.analysisVersion = analysisVersion
        self.limitation = limitation
    }
}

public enum VocalExecutionMode: String, Codable, CaseIterable, Sendable {
    case realtimeFullSourceActivation
    case offlineScopedAssetRender
}

public struct VocalExecutableProposal: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var candidateID: UUID
    public var intentID: UUID
    public var sourceSnapshotID: UUID
    public var scope: VocalCreativeScope
    public var executionMode: VocalExecutionMode
    public var processingBoundary: VocalProcessingBoundary
    public var plan: ProcessingPlan
    public var exactNodeIDs: [UUID]
    public var validationIdentity: String
    public var validatedAt: Date

    public init(
        version: VocalSchemaVersion = .v1,
        candidateID: UUID,
        intentID: UUID,
        sourceSnapshotID: UUID,
        scope: VocalCreativeScope,
        executionMode: VocalExecutionMode,
        processingBoundary: VocalProcessingBoundary,
        plan: ProcessingPlan,
        exactNodeIDs: [UUID],
        validationIdentity: String,
        validatedAt: Date
    ) {
        self.version = version
        self.candidateID = candidateID
        self.intentID = intentID
        self.sourceSnapshotID = sourceSnapshotID
        self.scope = scope
        self.executionMode = executionMode
        self.processingBoundary = processingBoundary
        self.plan = plan
        self.exactNodeIDs = exactNodeIDs
        self.validationIdentity = validationIdentity
        self.validatedAt = validatedAt
    }
}

public struct VocalCaptureHandoffAuthority: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var captureBriefID: UUID?
    public var selectedCaptureInterpretationID: UUID?
    public var testTakeAssessmentID: UUID?
    public var confirmedPreferenceID: UUID?
    public var sourceAuthority: VocalSourceAuthority

    public init(
        version: VocalSchemaVersion = .v1,
        captureBriefID: UUID? = nil,
        selectedCaptureInterpretationID: UUID? = nil,
        testTakeAssessmentID: UUID? = nil,
        confirmedPreferenceID: UUID? = nil,
        sourceAuthority: VocalSourceAuthority
    ) {
        self.version = version
        self.captureBriefID = captureBriefID
        self.selectedCaptureInterpretationID = selectedCaptureInterpretationID
        self.testTakeAssessmentID = testTakeAssessmentID
        self.confirmedPreferenceID = confirmedPreferenceID
        self.sourceAuthority = sourceAuthority
    }
}

public enum VocalHandoffMutationAuthority: String, Codable, CaseIterable, Sendable {
    case explicitUserCreateIntentOnly
}

public struct VocalGuideCreateHandoff: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var createdAt: Date
    public var explicitUserIntentID: UUID
    public var mutationAuthority: VocalHandoffMutationAuthority
    public var reviewedKnowledgeIDs: [String]
    public var reviewedProcedureIDs: [String]
    public var relevantMeasurements: [VocalHandoffMeasurement]
    public var preservation: VocalPreservationContract
    public var stopConstraints: [String]
    public var rollbackConstraints: [String]
    public var captureAuthority: VocalCaptureHandoffAuthority
    public var proposal: VocalExecutableProposal
    public var providerProseHasMutationAuthority: Bool
    public var tutorModeHasMutationAuthority: Bool
    public var requiresFinalUserAction: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        createdAt: Date,
        explicitUserIntentID: UUID,
        mutationAuthority: VocalHandoffMutationAuthority = .explicitUserCreateIntentOnly,
        reviewedKnowledgeIDs: [String],
        reviewedProcedureIDs: [String],
        relevantMeasurements: [VocalHandoffMeasurement],
        preservation: VocalPreservationContract,
        stopConstraints: [String],
        rollbackConstraints: [String],
        captureAuthority: VocalCaptureHandoffAuthority,
        proposal: VocalExecutableProposal,
        providerProseHasMutationAuthority: Bool = false,
        tutorModeHasMutationAuthority: Bool = false,
        requiresFinalUserAction: Bool = true
    ) {
        self.version = version
        self.id = id
        self.createdAt = createdAt
        self.explicitUserIntentID = explicitUserIntentID
        self.mutationAuthority = mutationAuthority
        self.reviewedKnowledgeIDs = reviewedKnowledgeIDs
        self.reviewedProcedureIDs = reviewedProcedureIDs
        self.relevantMeasurements = relevantMeasurements
        self.preservation = preservation
        self.stopConstraints = stopConstraints
        self.rollbackConstraints = rollbackConstraints
        self.captureAuthority = captureAuthority
        self.proposal = proposal
        self.providerProseHasMutationAuthority = providerProseHasMutationAuthority
        self.tutorModeHasMutationAuthority = tutorModeHasMutationAuthority
        self.requiresFinalUserAction = requiresFinalUserAction
    }
}

public enum VocalHandoffError: Error, Equatable, CustomStringConvertible, Sendable {
    case explicitUserIntentRequired
    case invalidReviewedIdentifier(String)
    case staleSource
    case candidateNotLocallyValidated
    case invalidRealtimeScope
    case scopedAssetPermissionRequired
    case providerOrTutorAuthorityForbidden
    case planValidation(String)

    public var description: String {
        switch self {
        case .explicitUserIntentRequired: "Guide-to-Create handoff requires an explicit typed user Create intent."
        case let .invalidReviewedIdentifier(identifier): "Reviewed handoff identifier is empty or too large: \(identifier)."
        case .staleSource: "Guide-to-Create candidate and exact capture/source authority disagree."
        case .candidateNotLocallyValidated: "Only a locally validated vocal candidate may enter a Create handoff."
        case .invalidRealtimeScope: "Only a full-source candidate may be proposed for realtime activation."
        case .scopedAssetPermissionRequired: "A scoped Create proposal requires explicit typed permission for a local rendered asset."
        case .providerOrTutorAuthorityForbidden: "Provider prose and Tutor mode cannot receive mutation authority."
        case let .planValidation(reason): "Create handoff plan validation failed: \(reason)"
        }
    }
}

public struct VocalGuideCreateHandoffBuilder: Sendable {
    public init() {}

    public func build(
        handoffID: UUID,
        explicitUserIntentConfirmed: Bool,
        candidate: VocalCreativeCandidate,
        captureAuthority: VocalCaptureHandoffAuthority,
        reviewedKnowledgeIDs: [String],
        reviewedProcedureIDs: [String],
        relevantMeasurements: [VocalHandoffMeasurement],
        createdAt: Date,
        validationIdentity: String = "tracksmith.vocal.local-plan-validator.v1"
    ) throws -> VocalGuideCreateHandoff {
        guard explicitUserIntentConfirmed else { throw VocalHandoffError.explicitUserIntentRequired }
        guard candidate.authorityStatus == .locallyValidated else {
            throw VocalHandoffError.candidateNotLocallyValidated
        }
        guard candidate.intent.sourceSnapshotID == captureAuthority.sourceAuthority.sourceSnapshotID,
              candidate.plan.sourceSnapshotID == captureAuthority.sourceAuthority.sourceSnapshotID else {
            throw VocalHandoffError.staleSource
        }
        guard reviewedKnowledgeIDs.count <= 128,
              reviewedProcedureIDs.count <= 128,
              relevantMeasurements.count <= 64 else {
            throw VocalHandoffError.planValidation("Handoff references exceed bounded v1 limits.")
        }
        for identifier in reviewedKnowledgeIDs + reviewedProcedureIDs {
            guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  identifier.utf8.count <= 512 else {
                throw VocalHandoffError.invalidReviewedIdentifier(identifier)
            }
        }
        guard relevantMeasurements.allSatisfy({ measurement in
            !measurement.metricIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && measurement.value.isFinite
                && measurement.confidence.isFinite
                && (0...1).contains(measurement.confidence)
                && measurement.metricIdentifier.utf8.count <= 512
                && measurement.limitation.utf8.count <= 4_096
        }) else {
            throw VocalHandoffError.planValidation("A relevant measurement is nonfinite, unbounded, or unidentified.")
        }

        let executionMode: VocalExecutionMode
        do {
            if candidate.intent.scope.kind == .fullSource {
                guard candidate.realtimeActivatable else { throw VocalHandoffError.invalidRealtimeScope }
                try PlanValidator().validateForRealtimeActivation(
                    candidate.plan,
                    currentSnapshotID: captureAuthority.sourceAuthority.sourceSnapshotID
                )
                executionMode = .realtimeFullSourceActivation
            } else {
                guard !candidate.realtimeActivatable else { throw VocalHandoffError.invalidRealtimeScope }
                guard candidate.intent.assetAcceptance == .allowLocalRenderedAsset
                        || candidate.intent.assetAcceptance == .requireLocalRenderedAsset else {
                    throw VocalHandoffError.scopedAssetPermissionRequired
                }
                try PlanValidator().validate(
                    candidate.plan,
                    currentSnapshotID: captureAuthority.sourceAuthority.sourceSnapshotID
                )
                executionMode = .offlineScopedAssetRender
            }
            try VocalContractValidator().validate(candidate: candidate)
            _ = try CompiledGraph(
                plan: candidate.plan,
                sampleRate: captureAuthority.sourceAuthority.sampleRate,
                channelCount: captureAuthority.sourceAuthority.channelCount
            )
        } catch let error as VocalHandoffError {
            throw error
        } catch {
            throw VocalHandoffError.planValidation(String(describing: error))
        }

        let proposal = VocalExecutableProposal(
            candidateID: candidate.id,
            intentID: candidate.intent.id,
            sourceSnapshotID: candidate.intent.sourceSnapshotID,
            scope: candidate.intent.scope,
            executionMode: executionMode,
            processingBoundary: candidate.boundary,
            plan: candidate.plan,
            exactNodeIDs: candidate.plan.nodes.map(\.id),
            validationIdentity: validationIdentity,
            validatedAt: createdAt
        )
        return VocalGuideCreateHandoff(
            id: handoffID,
            createdAt: createdAt,
            explicitUserIntentID: candidate.intent.id,
            reviewedKnowledgeIDs: unique(reviewedKnowledgeIDs),
            reviewedProcedureIDs: unique(reviewedProcedureIDs),
            relevantMeasurements: relevantMeasurements,
            preservation: candidate.intent.preservation,
            stopConstraints: Array(candidate.intent.preservation.stopConditions.prefix(32)),
            rollbackConstraints: Array(candidate.intent.preservation.rollbackInstructions.prefix(32)),
            captureAuthority: captureAuthority,
            proposal: proposal,
            providerProseHasMutationAuthority: false,
            tutorModeHasMutationAuthority: false,
            requiresFinalUserAction: true
        )
    }

    public func validate(_ handoff: VocalGuideCreateHandoff) throws {
        guard !handoff.providerProseHasMutationAuthority,
              !handoff.tutorModeHasMutationAuthority,
              handoff.mutationAuthority == .explicitUserCreateIntentOnly,
              handoff.requiresFinalUserAction else {
            throw VocalHandoffError.providerOrTutorAuthorityForbidden
        }
        guard handoff.explicitUserIntentID == handoff.proposal.intentID,
              handoff.proposal.sourceSnapshotID == handoff.captureAuthority.sourceAuthority.sourceSnapshotID,
              handoff.proposal.plan.sourceSnapshotID == handoff.proposal.sourceSnapshotID,
              handoff.proposal.exactNodeIDs == handoff.proposal.plan.nodes.map(\.id),
              handoff.proposal.plan.scope.timeRangeSeconds == (
                handoff.proposal.scope.kind == .fullSource ? nil : handoff.proposal.scope.seconds
              ) else {
            throw VocalHandoffError.staleSource
        }
        guard handoff.reviewedKnowledgeIDs.count <= 128,
              handoff.reviewedProcedureIDs.count <= 128,
              handoff.relevantMeasurements.count <= 64,
              (handoff.reviewedKnowledgeIDs + handoff.reviewedProcedureIDs).allSatisfy({
                  !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 512
              }),
              handoff.relevantMeasurements.allSatisfy({
                  !$0.metricIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && $0.value.isFinite
                      && $0.confidence.isFinite
                      && (0...1).contains($0.confidence)
              }) else {
            throw VocalHandoffError.planValidation("Stored handoff references or measurements exceed bounded validation.")
        }
        switch handoff.proposal.executionMode {
        case .realtimeFullSourceActivation:
            guard handoff.proposal.scope.kind == .fullSource else {
                throw VocalHandoffError.invalidRealtimeScope
            }
            do {
                try PlanValidator().validateForRealtimeActivation(
                    handoff.proposal.plan,
                    currentSnapshotID: handoff.proposal.sourceSnapshotID
                )
            } catch {
                throw VocalHandoffError.planValidation(String(describing: error))
            }
        case .offlineScopedAssetRender:
            guard handoff.proposal.scope.kind != .fullSource,
                  handoff.proposal.processingBoundary == .scopedEditablePlanForOfflineRender else {
                throw VocalHandoffError.planValidation("Offline scoped proposal unexpectedly has full-source scope.")
            }
            do {
                try PlanValidator().validate(
                    handoff.proposal.plan,
                    currentSnapshotID: handoff.proposal.sourceSnapshotID
                )
            } catch {
                throw VocalHandoffError.planValidation(String(describing: error))
            }
        }
        do {
            _ = try CompiledGraph(
                plan: handoff.proposal.plan,
                sampleRate: handoff.captureAuthority.sourceAuthority.sampleRate,
                channelCount: handoff.captureAuthority.sourceAuthority.channelCount
            )
        } catch {
            throw VocalHandoffError.planValidation(String(describing: error))
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
