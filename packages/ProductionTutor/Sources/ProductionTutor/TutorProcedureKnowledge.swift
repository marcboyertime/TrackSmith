import CryptoKit
import Foundation
import PlanSchema

public struct TutorSourceReference: Codable, Equatable, Sendable {
    public var sourceIdentity: String
    public var relevantSection: String
    public var provenanceClass: TutorEvidenceProvenanceClass

    public init(
        sourceIdentity: String,
        relevantSection: String,
        provenanceClass: TutorEvidenceProvenanceClass
    ) {
        self.sourceIdentity = sourceIdentity
        self.relevantSection = relevantSection
        self.provenanceClass = provenanceClass
    }
}

/// One reviewed, versioned, bounded manual procedure. All exact Logic
/// instructions in a lesson are materialized from these entries; providers can
/// only reference them by ID.
public struct TutorProcedure: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var version: String
    public var logicVersionScope: String
    public var supportedSourceTypes: [SourceType]
    public var supportedIssues: [TutorIssueKind]
    public var candidateCauses: [TutorCauseCategory]
    public var prerequisiteQuestions: [String]
    public var processorIdentities: [String]
    public var entryStepID: String
    public var steps: [TutorStep]
    public var preservationRequirements: [String]
    public var stoppingRules: [String]
    public var contraindications: [String]
    public var knownFailureModes: [String]
    public var nonDSPAlternativeProcedureIDs: [String]
    public var sourceReferences: [TutorSourceReference]
    public var empiricalRunIDs: [String]
    public var subjectiveListeningBoundary: String
    /// Must always be false: procedures describe user actions and grant
    /// TrackSmith no execution authority over Logic.
    public var grantsExecutionAuthority: Bool

    public init(
        id: String,
        version: String,
        logicVersionScope: String,
        supportedSourceTypes: [SourceType],
        supportedIssues: [TutorIssueKind],
        candidateCauses: [TutorCauseCategory],
        prerequisiteQuestions: [String],
        processorIdentities: [String],
        entryStepID: String,
        steps: [TutorStep],
        preservationRequirements: [String],
        stoppingRules: [String],
        contraindications: [String],
        knownFailureModes: [String],
        nonDSPAlternativeProcedureIDs: [String],
        sourceReferences: [TutorSourceReference],
        empiricalRunIDs: [String],
        subjectiveListeningBoundary: String,
        grantsExecutionAuthority: Bool
    ) {
        self.id = id
        self.version = version
        self.logicVersionScope = logicVersionScope
        self.supportedSourceTypes = supportedSourceTypes
        self.supportedIssues = supportedIssues
        self.candidateCauses = candidateCauses
        self.prerequisiteQuestions = prerequisiteQuestions
        self.processorIdentities = processorIdentities
        self.entryStepID = entryStepID
        self.steps = steps
        self.preservationRequirements = preservationRequirements
        self.stoppingRules = stoppingRules
        self.contraindications = contraindications
        self.knownFailureModes = knownFailureModes
        self.nonDSPAlternativeProcedureIDs = nonDSPAlternativeProcedureIDs
        self.sourceReferences = sourceReferences
        self.empiricalRunIDs = empiricalRunIDs
        self.subjectiveListeningBoundary = subjectiveListeningBoundary
        self.grantsExecutionAuthority = grantsExecutionAuthority
    }

    public func step(_ stepID: String) -> TutorStep? {
        steps.first { $0.id == stepID }
    }
}

public struct TutorProcedureCatalog: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var logicVersion: String
    public var reviewedAt: String
    public var recognizedProcessorIdentities: [String]
    public var procedures: [TutorProcedure]

    public init(
        schemaVersion: String,
        logicVersion: String,
        reviewedAt: String,
        recognizedProcessorIdentities: [String],
        procedures: [TutorProcedure]
    ) {
        self.schemaVersion = schemaVersion
        self.logicVersion = logicVersion
        self.reviewedAt = reviewedAt
        self.recognizedProcessorIdentities = recognizedProcessorIdentities
        self.procedures = procedures
    }

    public func procedure(_ id: String) -> TutorProcedure? {
        procedures.first { $0.id == id }
    }
}

public enum TutorProcedureCatalogError: Error, Equatable, Sendable {
    case generatedArtifactChecksumMismatch(expected: String, actual: String)
    case decodingFailed(String)
}

public extension TutorProcedureCatalog {
    /// Loads and fully validates the generated catalog. Fails closed: no
    /// partially valid catalog is ever returned.
    static func loadValidated() throws -> TutorProcedureCatalog {
        let payload = Data(TutorProcedureKnowledgeGenerated.catalogJSON.utf8)
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        guard digest == TutorProcedureKnowledgeGenerated.sourceArtifactSHA256 else {
            throw TutorProcedureCatalogError.generatedArtifactChecksumMismatch(
                expected: TutorProcedureKnowledgeGenerated.sourceArtifactSHA256,
                actual: digest
            )
        }
        let catalog: TutorProcedureCatalog
        do {
            catalog = try JSONDecoder().decode(TutorProcedureCatalog.self, from: payload)
        } catch {
            throw TutorProcedureCatalogError.decodingFailed(String(describing: error))
        }
        try TutorKnowledgeValidator().validate(catalog)
        return catalog
    }
}
