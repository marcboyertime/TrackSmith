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

public struct DeterministicPlanner: Sendable {
    public init() {}

    public func parseGoals(prompt: String, sourceType: SourceType) throws -> [ProcessingGoal] {
        let text = prompt.lowercased()
        if text.contains("louder") && text.contains("same loudness") { throw PlannerError.contradictoryRequest("The request simultaneously changes and preserves loudness.") }
        if (text.contains("remove all dynamics") || text.contains("remove dynamics"))
            && (text.contains("preserve all dynamics") || text.contains("keep all dynamics")) {
            throw PlannerError.contradictoryRequest("The request simultaneously removes and preserves dynamics.")
        }
        if text.contains("ignore") && text.contains("lock") {
            throw PlannerError.unsupportedRequest("Locked processing is a hard constraint and cannot be ignored by a prompt.")
        }
        if text.contains("shell command") || text.contains("delete the original") || text.contains("upload my entire") {
            throw PlannerError.unsupportedRequest("The audio planner has no shell, deletion, or unapproved upload capability.")
        }
        if containsOutOfBoundsDecibelRequest(text) {
            throw PlannerError.unsupportedRequest("Direct gain requests beyond 24 dB are outside the validated processing schema.")
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

    private func containsOutOfBoundsDecibelRequest(_ text: String) -> Bool {
        guard let expression = try? NSRegularExpression(
            pattern: #"([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*db\b"#,
            options: [.caseInsensitive]
        ) else { return true }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).contains { match in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]) else { return true }
            return abs(value) > 24
        }
    }

    public func variants(prompt: String, sourceSnapshotID: UUID, scope: ProcessingScope, analysis: AnalysisReport? = nil) throws -> [PlanVariant] {
        let goals = try parseGoals(prompt: prompt, sourceType: scope.sourceType)
        return try PreviewStrength.allCases.map { strength in
            // The spacing is deliberately nonlinear. Closely spaced presets are
            // difficult to compare reliably after loudness matching.
            let amount: Double = switch strength { case .conservative: 0.20; case .balanced: 1.20; case .strong: 2.80 }
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
        let wantsSibilanceReduction = goals.contains { $0.attribute == .sibilance && $0.direction == .decrease }
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
            let measuredRMS = analysis?.metrics["rms_dbfs"]?.value ?? -22
            let crest = min(max(analysis?.metrics["crest_factor"]?.value ?? 3, 1.42), 12)
            // Giannoulis et al. derive program-dependent time constants from
            // 2*tMax/crest^2. Keep musical clamps and use a slower attack for
            // explicit punch preservation.
            let automaticAttack = min(80, max(5, 160 / (crest * crest)))
            let isVocal = sourceType == .vocal || sourceType == .vocalBus
            let attack = wantsPunch ? max(22, automaticAttack * 1.7) : (isVocal ? max(14, automaticAttack) : automaticAttack)
            let minimumRelease = isVocal ? 90.0 : 60.0
            let automaticRelease = min(500, max(minimumRelease, 2_000 / (crest * crest) - attack))
            // Reference threshold to measured programme RMS so the same request
            // remains effective on quiet and hot recordings.
            let threshold = min(-3, max(-48, measuredRMS + 3.2 - 3.8 * (amount - 1)))
            nodes.append(.init(type: .compressor, parameters: [
                .thresholdDB: threshold, .ratio: 1.35 + 1.18 * amount, .attackMS: attack,
                .releaseMS: automaticRelease, .makeupGainDB: 0, .kneeDB: 4 + 3 * amount, .mix: wantsPunch ? 0.78 : 1,
            ], rationale: wantsPunch ? "Use signal-dependent timing to control sustain while preserving leading transients and groove." : "Reference threshold and timing to the captured signal instead of applying a fixed compressor preset.", confidence: analysis == nil ? 0.62 : 0.82, category: .corrective))
        }
        if wantsSibilanceReduction && (sourceType == .vocal || sourceType == .vocalBus) {
            let detectorRMS = analysis?.metrics["sibilance_detector_rms_dbfs"]?.value ?? -32
            let threshold = min(-10, max(-42, detectorRMS + 6 - 2.5 * (amount - 1)))
            nodes.append(.init(type: .deEsser, parameters: [
                .frequencyHz: 6_500,
                .thresholdDB: threshold,
                .ratio: 1.6 + 1.4 * amount,
                .attackMS: 1.5,
                .releaseMS: 70,
                .mix: min(1, 0.55 + 0.2 * amount),
            ], rationale: "Reduce only the upper split band when sibilant energy crosses a signal-relative threshold.", confidence: analysis == nil ? 0.55 : 0.72, category: .corrective))
        }
        if protectHighs {
            nodes.append(.init(type: .parametricEQ, parameters: [.frequencyHz: 8_500, .q: 0.6, .gainDB: -0.5 * amount], rationale: "Guard against an unintended increase in upper-frequency harshness.", confidence: 0.55, category: .corrective, locked: true))
        }
        nodes.append(.init(type: .limiter, parameters: [.ceilingDB: -1, .releaseMS: 80, .lookaheadMS: 0], rationale: "Catch unsafe sample peaks; this is not used as a loudness maximizer.", confidence: 0.9, category: .loudness))
        return nodes
    }
}
