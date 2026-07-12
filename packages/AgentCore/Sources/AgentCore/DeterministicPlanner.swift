import AudioAnalysis
import Foundation
import PlanSchema

public enum PreviewStrength: String, Codable, CaseIterable, Sendable { case conservative, balanced, strong }

public struct PlanVariant: Codable, Equatable, Sendable {
    public var strength: PreviewStrength
    public var plan: ProcessingPlan
    public init(strength: PreviewStrength, plan: ProcessingPlan) { self.strength = strength; self.plan = plan }
}

public enum PlannerError: Error, Equatable, Sendable { case contradictoryRequest(String), unsupportedRequest(String) }

public protocol ModelProvider: Sendable {
    var identifier: String { get }
    func goals(for prompt: String, sourceType: SourceType) async throws -> [ProcessingGoal]
}

public struct MockModelProvider: ModelProvider {
    public let identifier = "mock-offline-1"
    public init() {}
    public func goals(for prompt: String, sourceType: SourceType) async throws -> [ProcessingGoal] {
        try DeterministicPlanner().parseGoals(prompt: prompt, sourceType: sourceType)
    }
}

public struct DeterministicPlanner: Sendable {
    public init() {}

    public func parseGoals(prompt: String, sourceType: SourceType) throws -> [ProcessingGoal] {
        let text = prompt.lowercased()
        if text.contains("louder") && text.contains("same loudness") { throw PlannerError.contradictoryRequest("The request simultaneously changes and preserves loudness.") }
        if text.contains("shell command") || text.contains("delete the original") || text.contains("upload my entire") {
            throw PlannerError.unsupportedRequest("The audio planner has no shell, deletion, or unapproved upload capability.")
        }
        var goals: [ProcessingGoal] = []
        func add(_ attribute: GoalAttribute, _ direction: GoalDirection, _ strength: Double = 0.6, locked: Bool = false) {
            if !goals.contains(where: { $0.attribute == attribute }) { goals.append(.init(attribute: attribute, direction: direction, strength: strength, locked: locked)) }
        }
        if text.contains("clear") || text.contains("professional") { add(.clarity, .increase) }
        if text.contains("warm") { add(.warmth, .increase) }
        if text.contains("control") || text.contains("compress") { add(.dynamicControl, .increase) }
        if text.contains("punch") || text.contains("hit harder") { add(.punch, .increase) }
        if text.contains("harsh") { add(.harshness, text.contains("without") || text.contains("do not") ? .doNotIncrease : .decrease, 1, locked: true) }
        if text.contains("cymbal") { add(.cymbalHarshness, .doNotIncrease, 1, locked: true) }
        if text.contains("sibil") { add(.sibilance, .decrease) }
        if text.contains("box") || text.contains("mud") { add(.muddiness, .decrease) }
        if text.contains("wide") { add(.width, .increase) }
        if goals.isEmpty { add(sourceType == .drums || sourceType == .drumBus ? .punch : .clarity, .increase, 0.4) }
        return goals
    }

    public func variants(prompt: String, sourceSnapshotID: UUID, scope: ProcessingScope, analysis: AnalysisReport? = nil) throws -> [PlanVariant] {
        let goals = try parseGoals(prompt: prompt, sourceType: scope.sourceType)
        return try PreviewStrength.allCases.map { strength in
            let amount: Double = switch strength { case .conservative: 0.55; case .balanced: 1; case .strong: 1.45 }
            let nodes = recipe(sourceType: scope.sourceType, goals: goals, amount: amount, analysis: analysis)
            let plan = ProcessingPlan(sourceSnapshotID: sourceSnapshotID, scope: scope, goals: goals, nodes: nodes)
            try PlanValidator().validate(plan, currentSnapshotID: sourceSnapshotID)
            return PlanVariant(strength: strength, plan: plan)
        }
    }

    private func recipe(sourceType: SourceType, goals: [ProcessingGoal], amount: Double, analysis: AnalysisReport?) -> [ProcessingNode] {
        var nodes: [ProcessingNode] = []
        let wantsClarity = goals.contains { $0.attribute == .clarity || $0.attribute == .muddiness }
        let wantsWarmth = goals.contains { $0.attribute == .warmth }
        let wantsControl = goals.contains { $0.attribute == .dynamicControl }
        let wantsPunch = goals.contains { $0.attribute == .punch }
        let protectHighs = goals.contains { $0.attribute == .harshness || $0.attribute == .cymbalHarshness }

        if sourceType == .vocal || sourceType == .vocalBus {
            nodes.append(.init(type: .highPass, parameters: [.frequencyHz: 70 + 15 * amount, .q: 0.707], rationale: "Reduce subsonic and proximity buildup without thinning the vocal.", confidence: 0.82, category: .corrective))
        }
        if wantsClarity {
            nodes.append(.init(type: .parametricEQ, parameters: [.frequencyHz: sourceType == .vocal ? 320 : 280, .q: 1.1, .gainDB: -1.6 * amount], rationale: "Reduce a restrained amount of boxy low-mid energy.", confidence: 0.72, category: .corrective))
            nodes.append(.init(type: .parametricEQ, parameters: [.frequencyHz: 3_200, .q: 0.85, .gainDB: 1.25 * amount], rationale: "Add presence for intelligibility without relying on output level.", confidence: protectHighs ? 0.58 : 0.7, category: .corrective))
        }
        if wantsWarmth {
            nodes.append(.init(type: .saturation, parameters: [.driveDB: 2.5 * amount, .mix: min(0.45, 0.22 * amount)], rationale: "Add low-order nonlinear density while retaining the dry signal.", confidence: 0.66, category: .creative))
        }
        if wantsPunch && (sourceType == .drums || sourceType == .drumBus) {
            nodes.append(.init(type: .parametricEQ, parameters: [.frequencyHz: 85, .q: 0.8, .gainDB: 1.2 * amount], rationale: "Support low-frequency drum impact conservatively.", confidence: 0.64, category: .corrective))
        }
        if wantsControl || wantsPunch {
            let attack = wantsPunch ? 28 : 18
            nodes.append(.init(type: .compressor, parameters: [
                .thresholdDB: -16 - 2 * amount, .ratio: 1.4 + 1.1 * amount, .attackMS: Double(attack),
                .releaseMS: wantsPunch ? 95 : 130, .makeupGainDB: 0.6 * amount, .kneeDB: 6, .mix: wantsPunch ? 0.75 : 1,
            ], rationale: wantsPunch ? "Control sustain while preserving leading transients and groove." : "Reduce phrase-level variation with moderate timing and ratio.", confidence: 0.78, category: .corrective))
        }
        if protectHighs {
            nodes.append(.init(type: .parametricEQ, parameters: [.frequencyHz: 8_500, .q: 0.6, .gainDB: -0.5 * amount], rationale: "Guard against an unintended increase in upper-frequency harshness.", confidence: 0.55, category: .corrective, locked: true))
        }
        nodes.append(.init(type: .limiter, parameters: [.ceilingDB: -1, .releaseMS: 80, .lookaheadMS: 0], rationale: "Catch unsafe sample peaks; this is not used as a loudness maximizer.", confidence: 0.9, category: .loudness))
        return nodes
    }
}
