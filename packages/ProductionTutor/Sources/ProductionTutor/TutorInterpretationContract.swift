import AgentCore
import Foundation
import PlanSchema

/// Bounded symbolic proposal a provider may make about a tutor request. It may
/// only reference canonical local IDs; it can never contain menu paths, control
/// names, parameter values, key commands, host actions, or claims that an
/// action occurred. The deterministic local planner remains the only authority
/// that materializes instructions.
public struct TutorInterpretationProposal: Codable, Equatable, Sendable {
    public var version: String
    public var requestKind: TutorRequestKind
    public var issueIDs: [String]
    public var causeIDs: [String]
    public var desiredProductionTermIDs: [String]
    public var preservationProductionTermIDs: [String]
    public var requiresClarification: Bool
    public var clarificationQuestion: String?
    public var procedureIDs: [String]
    public var uncertainty: [String]
    public var confidence: Double

    public init(
        version: String = "1.0",
        requestKind: TutorRequestKind,
        issueIDs: [String],
        causeIDs: [String],
        desiredProductionTermIDs: [String] = [],
        preservationProductionTermIDs: [String] = [],
        requiresClarification: Bool = false,
        clarificationQuestion: String? = nil,
        procedureIDs: [String] = [],
        uncertainty: [String] = [],
        confidence: Double = 0.5
    ) {
        self.version = version
        self.requestKind = requestKind
        self.issueIDs = issueIDs
        self.causeIDs = causeIDs
        self.desiredProductionTermIDs = desiredProductionTermIDs
        self.preservationProductionTermIDs = preservationProductionTermIDs
        self.requiresClarification = requiresClarification
        self.clarificationQuestion = clarificationQuestion
        self.procedureIDs = procedureIDs
        self.uncertainty = uncertainty
        self.confidence = confidence
    }
}

public enum TutorProposalValidationStage: String, Codable, CaseIterable, Sendable {
    case decoding
    case schema
    case semantic
    case capability
    case knowledgeReference
    case stateReference
    case instructionConstraint
}

public enum TutorProposalValidationError: Error, Equatable, Sendable {
    case failed(stage: TutorProposalValidationStage, reason: String)
}

public struct TutorProposalValidationAudit: Codable, Equatable, Sendable {
    public var completedStages: [TutorProposalValidationStage]

    public init(completedStages: [TutorProposalValidationStage]) {
        self.completedStages = completedStages
    }
}

/// Staged validation for provider tutor proposals, mirroring the Production
/// Intelligence discipline. Every referenced ID must resolve locally; any
/// instruction-like content fails closed.
public struct TutorProposalValidator: Sendable {
    private let catalog: TutorProcedureCatalog

    /// JSON keys that indicate the provider tried to author instructions or
    /// host actions rather than bounded symbols.
    public static let forbiddenPayloadKeys: [String] = [
        "menuPath", "menu_path", "keyCommand", "key_command", "coordinates",
        "controlName", "control_name", "parameterValue", "parameter_value",
        "parameters", "shell", "appleScript", "applescript", "accessibility",
        "actionPerformed", "action_performed", "hostState", "host_state",
        "pluginName", "plugin_name", "steps", "instruction",
    ]

    /// Phrases that claim an action occurred or a host state was observed.
    public static let forbiddenPayloadPhrases: [String] = [
        "i changed", "i clicked", "i adjusted", "i opened", "logic is set to",
        "logic is currently", "was applied to your session", "i bypassed",
    ]

    public static let maximumListEntries = 8
    public static let maximumTextBytes = 2_048

    public init(catalog: TutorProcedureCatalog) {
        self.catalog = catalog
    }

    public func validate(payload: Data) throws -> (TutorInterpretationProposal, TutorProposalValidationAudit) {
        var completed: [TutorProposalValidationStage] = []

        // decoding
        guard let object = try? JSONSerialization.jsonObject(with: payload),
              let dictionary = object as? [String: Any] else {
            throw TutorProposalValidationError.failed(stage: .decoding, reason: "Payload is not a JSON object.")
        }
        completed.append(.decoding)

        // schema: forbidden keys anywhere in the payload fail closed before
        // typed decoding can silently drop them.
        try Self.scanKeys(dictionary, stage: .schema)
        let proposal: TutorInterpretationProposal
        do {
            proposal = try JSONDecoder().decode(TutorInterpretationProposal.self, from: payload)
        } catch {
            throw TutorProposalValidationError.failed(stage: .schema, reason: String(describing: error))
        }
        guard proposal.version == "1.0" else {
            throw TutorProposalValidationError.failed(stage: .schema, reason: "Unsupported proposal version.")
        }
        completed.append(.schema)

        // semantic: bounded sizes, finite confidence, clarification coherence.
        for list in [
            proposal.issueIDs, proposal.causeIDs, proposal.procedureIDs,
            proposal.desiredProductionTermIDs, proposal.preservationProductionTermIDs,
            proposal.uncertainty,
        ] {
            guard list.count <= Self.maximumListEntries else {
                throw TutorProposalValidationError.failed(stage: .semantic, reason: "A list exceeds the bounded entry count.")
            }
        }
        guard proposal.confidence.isFinite, proposal.confidence >= 0, proposal.confidence <= 1 else {
            throw TutorProposalValidationError.failed(stage: .semantic, reason: "Confidence out of range.")
        }
        if proposal.requiresClarification {
            guard let question = proposal.clarificationQuestion,
                  !question.trimmingCharacters(in: .whitespaces).isEmpty,
                  question.utf8.count <= Self.maximumTextBytes else {
                throw TutorProposalValidationError.failed(stage: .semantic, reason: "Clarification flagged without a bounded question.")
            }
        }
        completed.append(.semantic)

        // capability: proposals cannot claim actions or host observation.
        let corpus = (proposal.uncertainty + [proposal.clarificationQuestion ?? ""])
            .joined(separator: " ").lowercased()
        for phrase in Self.forbiddenPayloadPhrases where corpus.contains(phrase) {
            throw TutorProposalValidationError.failed(stage: .capability, reason: "Proposal claims an action or host state: \(phrase)")
        }
        completed.append(.capability)

        // knowledgeReference: every ID resolves to local vocabularies.
        let issueSet = Set(TutorIssueKind.allCases.map(\.rawValue))
        for identifier in proposal.issueIDs where !issueSet.contains(identifier) {
            throw TutorProposalValidationError.failed(stage: .knowledgeReference, reason: "Unknown issue ID \(identifier)")
        }
        let causeSet = Set(TutorCauseCategory.allCases.map(\.rawValue))
        for identifier in proposal.causeIDs where !causeSet.contains(identifier) {
            throw TutorProposalValidationError.failed(stage: .knowledgeReference, reason: "Unknown cause ID \(identifier)")
        }
        let procedureSet = Set(catalog.procedures.map(\.id))
        for identifier in proposal.procedureIDs where !procedureSet.contains(identifier) {
            throw TutorProposalValidationError.failed(stage: .knowledgeReference, reason: "Unknown procedure ID \(identifier)")
        }
        completed.append(.knowledgeReference)

        // stateReference: production terms must exist in the frozen vocabulary.
        let termSet = Set(ProductionTerm.allCases.map(\.rawValue))
        for identifier in proposal.desiredProductionTermIDs + proposal.preservationProductionTermIDs
            where !termSet.contains(identifier) {
            throw TutorProposalValidationError.failed(stage: .stateReference, reason: "Unknown production term \(identifier)")
        }
        completed.append(.stateReference)

        // instructionConstraint: no free text may look like an exact instruction.
        let instructionMarkers = ["click ", "press ", "drag ", "menu", "set the", "turn the knob", "db", "hz"]
        if let question = proposal.clarificationQuestion?.lowercased() {
            for marker in ["click ", "press ", "drag "] where question.contains(marker) {
                throw TutorProposalValidationError.failed(stage: .instructionConstraint, reason: "Clarification contains instruction-like content.")
            }
        }
        for text in proposal.uncertainty {
            let lowered = text.lowercased()
            var markerCount = 0
            for marker in instructionMarkers where lowered.contains(marker) { markerCount += 1 }
            if markerCount >= 2 {
                throw TutorProposalValidationError.failed(stage: .instructionConstraint, reason: "Uncertainty text contains instruction-like content.")
            }
        }
        completed.append(.instructionConstraint)

        return (proposal, TutorProposalValidationAudit(completedStages: completed))
    }

    private static func scanKeys(_ object: Any, stage: TutorProposalValidationStage) throws {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if forbiddenPayloadKeys.contains(key) {
                    throw TutorProposalValidationError.failed(stage: stage, reason: "Forbidden key \(key)")
                }
                try scanKeys(value, stage: stage)
            }
        } else if let array = object as? [Any] {
            for value in array { try scanKeys(value, stage: stage) }
        }
    }
}
