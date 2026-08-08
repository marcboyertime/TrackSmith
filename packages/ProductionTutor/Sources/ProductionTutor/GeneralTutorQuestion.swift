import Foundation
import PlanSchema

/// Structured project context the user may optionally supply. TrackSmith
/// cannot observe any of this; every field is user-reported by construction.
public struct GeneralTutorUserContext: Codable, Equatable, Sendable {
    public var sourceRole: String?
    public var genre: String?
    public var section: String?
    public var tempoBPM: Double?
    public var musicalKey: String?
    public var existingProcessors: [TutorReportedProcessor]
    public var processorsReported: Bool
    public var problemLocation: String?
    public var microphoneAndSetup: String?
    public var logicVersion: String?
    public var availablePlugins: [String]
    public var references: [String]
    public var skillLevel: String?
    public var preservationPriorities: [String]

    public init(
        sourceRole: String? = nil,
        genre: String? = nil,
        section: String? = nil,
        tempoBPM: Double? = nil,
        musicalKey: String? = nil,
        existingProcessors: [TutorReportedProcessor] = [],
        processorsReported: Bool = false,
        problemLocation: String? = nil,
        microphoneAndSetup: String? = nil,
        logicVersion: String? = nil,
        availablePlugins: [String] = [],
        references: [String] = [],
        skillLevel: String? = nil,
        preservationPriorities: [String] = []
    ) {
        self.sourceRole = sourceRole
        self.genre = genre
        self.section = section
        self.tempoBPM = tempoBPM
        self.musicalKey = musicalKey
        self.existingProcessors = existingProcessors
        self.processorsReported = processorsReported
        self.problemLocation = problemLocation
        self.microphoneAndSetup = microphoneAndSetup
        self.logicVersion = logicVersion
        self.availablePlugins = availablePlugins
        self.references = references
        self.skillLevel = skillLevel
        self.preservationPriorities = preservationPriorities
    }

    public static let empty = GeneralTutorUserContext()

    /// Every populated field rendered as an explicitly user-reported statement.
    public var reportedStatements: [String] {
        var out: [String] = []
        if let sourceRole { out.append("source role: \(sourceRole)") }
        if let genre { out.append("genre: \(genre)") }
        if let section { out.append("section: \(section)") }
        if let tempoBPM { out.append("tempo: \(Int(tempoBPM)) BPM") }
        if let musicalKey { out.append("key: \(musicalKey)") }
        if processorsReported {
            out.append(existingProcessors.isEmpty
                ? "channel processing: none reported"
                : "channel processing: " + existingProcessors.map(\.rawValue).sorted().joined(separator: ", "))
        }
        if let problemLocation { out.append("problem location: \(problemLocation)") }
        if let microphoneAndSetup { out.append("capture setup: \(microphoneAndSetup)") }
        if let logicVersion { out.append("Logic version: \(logicVersion)") }
        if !availablePlugins.isEmpty {
            out.append("available plug-ins: " + availablePlugins.joined(separator: ", "))
        }
        if !references.isEmpty { out.append("references: " + references.joined(separator: ", ")) }
        if let skillLevel { out.append("skill level: \(skillLevel)") }
        if !preservationPriorities.isEmpty {
            out.append("preserve: " + preservationPriorities.joined(separator: ", "))
        }
        return out
    }

    /// Bridges the optional context into the Tutor v1 chain type so the
    /// existing vocal fast path keeps working unchanged.
    public var tutorChain: TutorUserReportedChain {
        guard processorsReported else { return .unknown }
        return existingProcessors.isEmpty
            ? .none
            : TutorUserReportedChain(status: .reported, processors: existingProcessors)
    }
}

/// A typed, open-ended production question. Free-text fields are bounded
/// semantic descriptions for retrieval and display; they are never execution
/// authority and never become instructions.
public struct GeneralTutorQuestionIntent: Codable, Equatable, Sendable {
    public static let maximumSummaryBytes = 1_024
    public static let maximumListEntries = 12

    public var version: String
    public var questionID: UUID
    public var questionKind: GeneralQuestionKind
    public var primaryDomains: [ProductionDomain]
    public var secondaryDomains: [ProductionDomain]
    public var sourceType: SourceType
    public var problemSummary: String
    public var desiredOutcome: String
    public var namedEntities: [String]
    public var userContext: GeneralTutorUserContext
    public var preservationConstraints: [String]
    public var prohibitedOutcomes: [String]
    public var comparisonAlternatives: [String]
    public var explanationDepth: TutorExplanationDepth
    public var temporalScope: String?
    public var audioAvailable: Bool
    public var requiresProjectWideContext: Bool
    public var requestsExactLogicInstructions: Bool
    public var requiresCurrentResearch: Bool
    public var uncertainty: [String]
    public var requiresClarification: Bool
    public var clarificationQuestion: String?
    /// Recognized Tutor v1 issues, when the closed vocabulary also matched.
    /// Present as an accelerator, never as a precondition.
    public var recognizedTutorIssues: [TutorIssueKind]
    public var unsupportedRequests: [TutorUnsupportedRequest]

    public init(
        version: String = "1.0",
        questionID: UUID = UUID(),
        questionKind: GeneralQuestionKind,
        primaryDomains: [ProductionDomain],
        secondaryDomains: [ProductionDomain] = [],
        sourceType: SourceType,
        problemSummary: String,
        desiredOutcome: String,
        namedEntities: [String] = [],
        userContext: GeneralTutorUserContext = .empty,
        preservationConstraints: [String] = [],
        prohibitedOutcomes: [String] = [],
        comparisonAlternatives: [String] = [],
        explanationDepth: TutorExplanationDepth = .simple,
        temporalScope: String? = nil,
        audioAvailable: Bool = false,
        requiresProjectWideContext: Bool = false,
        requestsExactLogicInstructions: Bool = false,
        requiresCurrentResearch: Bool = false,
        uncertainty: [String] = [],
        requiresClarification: Bool = false,
        clarificationQuestion: String? = nil,
        recognizedTutorIssues: [TutorIssueKind] = [],
        unsupportedRequests: [TutorUnsupportedRequest] = []
    ) {
        self.version = version
        self.questionID = questionID
        self.questionKind = questionKind
        self.primaryDomains = Array(primaryDomains.prefix(Self.maximumListEntries))
        self.secondaryDomains = Array(secondaryDomains.prefix(Self.maximumListEntries))
        self.sourceType = sourceType
        self.problemSummary = Self.bounded(problemSummary)
        self.desiredOutcome = Self.bounded(desiredOutcome)
        self.namedEntities = Array(namedEntities.prefix(Self.maximumListEntries))
        self.userContext = userContext
        self.preservationConstraints = Array(preservationConstraints.prefix(Self.maximumListEntries))
        self.prohibitedOutcomes = Array(prohibitedOutcomes.prefix(Self.maximumListEntries))
        self.comparisonAlternatives = Array(comparisonAlternatives.prefix(Self.maximumListEntries))
        self.explanationDepth = explanationDepth
        self.temporalScope = temporalScope
        self.audioAvailable = audioAvailable
        self.requiresProjectWideContext = requiresProjectWideContext
        self.requestsExactLogicInstructions = requestsExactLogicInstructions
        self.requiresCurrentResearch = requiresCurrentResearch
        self.uncertainty = uncertainty
        self.requiresClarification = requiresClarification
        self.clarificationQuestion = clarificationQuestion
        self.recognizedTutorIssues = recognizedTutorIssues
        self.unsupportedRequests = unsupportedRequests
    }

    public var allDomains: [ProductionDomain] {
        var seen = Set<ProductionDomain>()
        return (primaryDomains + secondaryDomains).filter { seen.insert($0).inserted }
    }

    private static func bounded(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.utf8.count > maximumSummaryBytes, !result.isEmpty { result.removeLast() }
        return result
    }
}
