import Foundation

public enum PlanValidationError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidTimeRange
    case duplicateNodeID(UUID)
    case unsupportedParameter(NodeType, ParameterID)
    case parameterOutOfRange(ParameterID, value: Double, allowed: ClosedRange<Double>)
    case invalidConfidence(Double)
    case invalidGoalStrength(Double)
    case excessiveGain(Double)
    case staleSourceSnapshot(expected: UUID, actual: UUID)
    case lockedNodeModified(UUID)

    public var description: String {
        switch self {
        case .invalidTimeRange: "The analysis time range must be finite, nonnegative, and increasing."
        case let .duplicateNodeID(id): "Duplicate processing node ID: \(id)."
        case let .unsupportedParameter(type, id): "Parameter \(id.rawValue) is unsupported for \(type.rawValue)."
        case let .parameterOutOfRange(id, value, allowed): "\(id.rawValue)=\(value) is outside \(allowed)."
        case let .invalidConfidence(value): "Confidence \(value) is outside 0...1."
        case let .invalidGoalStrength(value): "Goal strength \(value) is outside 0...1."
        case let .excessiveGain(value): "Cumulative requested gain \(value) dB exceeds the plan limit."
        case let .staleSourceSnapshot(expected, actual): "Plan targets \(actual), but current snapshot is \(expected)."
        case let .lockedNodeModified(id): "Locked node \(id) was modified or removed."
        }
    }
}

public struct PlanValidator: Sendable {
    public init() {}

    public static let ranges: [ParameterID: ClosedRange<Double>] = [
        .gainDB: -60...24, .frequencyHz: 10...24_000, .q: 0.1...20,
        .thresholdDB: -80...0, .ratio: 1...40, .attackMS: 0.05...500,
        .releaseMS: 1...5_000, .makeupGainDB: -24...24, .ceilingDB: -24...0,
        .kneeDB: 0...24, .mix: 0...1, .width: 0...2, .driveDB: 0...36,
        .enabled: 0...1, .lookaheadMS: 0...20,
    ]

    public static let allowedParameters: [NodeType: Set<ParameterID>] = [
        .inputTrim: [.gainDB], .polarity: [], .highPass: [.frequencyHz, .q], .lowPass: [.frequencyHz, .q],
        .parametricEQ: [.frequencyHz, .q, .gainDB], .compressor: [.thresholdDB, .ratio, .attackMS, .releaseMS, .makeupGainDB, .kneeDB, .mix],
        .expander: [.thresholdDB, .ratio, .attackMS, .releaseMS, .mix], .deEsser: [.frequencyHz, .thresholdDB, .ratio, .attackMS, .releaseMS, .mix],
        .softClipper: [.driveDB, .ceilingDB, .mix], .saturation: [.driveDB, .mix], .transientShaper: [.gainDB, .mix],
        .stereoWidth: [.width, .mix], .midSideEQ: [.frequencyHz, .q, .gainDB, .mix], .delay: [.mix], .reverb: [.mix],
        .limiter: [.ceilingDB, .releaseMS, .lookaheadMS], .outputTrim: [.gainDB], .loudnessMatch: [.gainDB], .meter: [],
    ]

    public func validate(_ plan: ProcessingPlan, currentSnapshotID: UUID? = nil, basePlan: ProcessingPlan? = nil) throws {
        if let range = plan.scope.timeRangeSeconds,
           !range.start.isFinite || !range.end.isFinite || range.start < 0 || range.end <= range.start {
            throw PlanValidationError.invalidTimeRange
        }
        if let currentSnapshotID, plan.sourceSnapshotID != currentSnapshotID {
            throw PlanValidationError.staleSourceSnapshot(expected: currentSnapshotID, actual: plan.sourceSnapshotID)
        }
        for goal in plan.goals where !goal.strength.isFinite || !(0...1).contains(goal.strength) {
            throw PlanValidationError.invalidGoalStrength(goal.strength)
        }
        var ids = Set<UUID>()
        var addedGain = 0.0
        for node in plan.nodes {
            guard ids.insert(node.id).inserted else { throw PlanValidationError.duplicateNodeID(node.id) }
            guard node.confidence.isFinite, (0...1).contains(node.confidence) else { throw PlanValidationError.invalidConfidence(node.confidence) }
            let allowed = Self.allowedParameters[node.type, default: []]
            for (parameter, value) in node.parameters {
                guard allowed.contains(parameter) else { throw PlanValidationError.unsupportedParameter(node.type, parameter) }
                guard let range = Self.ranges[parameter], value.isFinite, range.contains(value) else {
                    throw PlanValidationError.parameterOutOfRange(parameter, value: value, allowed: Self.ranges[parameter] ?? 0...0)
                }
                if node.enabled, [.gainDB, .makeupGainDB, .driveDB].contains(parameter), value > 0 { addedGain += value }
            }
        }
        guard addedGain <= plan.outputConstraints.maxAddedGainDB else { throw PlanValidationError.excessiveGain(addedGain) }
        if let basePlan {
            let candidates = Dictionary(uniqueKeysWithValues: plan.nodes.map { ($0.id, $0) })
            for original in basePlan.nodes where original.locked {
                guard candidates[original.id] == original else { throw PlanValidationError.lockedNodeModified(original.id) }
            }
        }
    }
}
