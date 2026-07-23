import Foundation

public enum PlanValidationError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidTimeRange
    case duplicateNodeID(UUID)
    case unsupportedNode(NodeType)
    case unsupportedParameter(NodeType, ParameterID)
    case parameterOutOfRange(ParameterID, value: Double, allowed: ClosedRange<Double>)
    case invalidConfidence(Double)
    case invalidGoalStrength(Double)
    case invalidOutputConstraint(String, Double)
    case planTooComplex(nodes: Int, goals: Int)
    case rationaleTooLong(UUID)
    case excessiveGain(Double)
    case missingFinalSafetyLimiter
    case safetyLimiterCeilingExceedsConstraint(ceilingDB: Double, maxTruePeakDB: Double)
    case staleSourceSnapshot(expected: UUID, actual: UUID)
    case lockedNodeModified(UUID)

    public var description: String {
        switch self {
        case .invalidTimeRange: "The analysis time range must be finite, nonnegative, and increasing."
        case let .duplicateNodeID(id): "Duplicate processing node ID: \(id)."
        case let .unsupportedNode(type): "Processing node \(type.rawValue) is not implemented in this engine version."
        case let .unsupportedParameter(type, id): "Parameter \(id.rawValue) is unsupported for \(type.rawValue)."
        case let .parameterOutOfRange(id, value, allowed): "\(id.rawValue)=\(value) is outside \(allowed)."
        case let .invalidConfidence(value): "Confidence \(value) is outside 0...1."
        case let .invalidGoalStrength(value): "Goal strength \(value) is outside 0...1."
        case let .invalidOutputConstraint(name, value): "Output constraint \(name)=\(value) is invalid."
        case let .planTooComplex(nodes, goals): "Plan complexity exceeds the bounded real-time budget: \(nodes) nodes, \(goals) goals."
        case let .rationaleTooLong(id): "Processing rationale for node \(id) exceeds the 4 KiB text limit."
        case let .excessiveGain(value): "Cumulative requested gain \(value) dB exceeds the plan limit."
        case .missingFinalSafetyLimiter: "Every non-dry real-time graph must end with an enabled safety limiter (meters may follow it)."
        case let .safetyLimiterCeilingExceedsConstraint(ceilingDB, maxTruePeakDB):
            "The final limiter ceiling (\(ceilingDB) dBFS) is above the plan peak constraint (\(maxTruePeakDB) dBTP)."
        case let .staleSourceSnapshot(expected, actual): "Plan targets \(actual), but current snapshot is \(expected)."
        case let .lockedNodeModified(id): "Locked node \(id) was modified or removed."
        }
    }
}

public struct PlanValidator: Sendable {
    public init() {}

    public static let maximumNodeCount = 32
    public static let maximumGoalCount = 32
    public static let maximumRationaleBytes = 4_096

    public static let ranges: [ParameterID: ClosedRange<Double>] = [
        .gainDB: -60...24, .frequencyHz: 10...24_000, .q: 0.1...20,
        .thresholdDB: -80...0, .ratio: 1...40, .attackMS: 0.05...500,
        .releaseMS: 1...5_000, .makeupGainDB: -24...24, .ceilingDB: -24...0,
        .kneeDB: 0...24, .mix: 0...1, .width: 0...2, .driveDB: 0...36,
        .enabled: 0...1, .lookaheadMS: 0...0,
    ]

    public static let implementedNodeTypes: Set<NodeType> = [
        .inputTrim, .polarity, .highPass, .lowPass, .parametricEQ, .compressor, .deEsser,
        .softClipper, .saturation, .stereoWidth, .limiter, .outputTrim, .loudnessMatch, .meter,
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
        guard plan.nodes.count <= Self.maximumNodeCount,
              plan.goals.count <= Self.maximumGoalCount else {
            throw PlanValidationError.planTooComplex(nodes: plan.nodes.count, goals: plan.goals.count)
        }
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
        guard plan.outputConstraints.maxTruePeakDB.isFinite,
              (-24...0).contains(plan.outputConstraints.maxTruePeakDB) else {
            throw PlanValidationError.invalidOutputConstraint("maxTruePeakDB", plan.outputConstraints.maxTruePeakDB)
        }
        guard plan.outputConstraints.maxAddedGainDB.isFinite,
              (0...24).contains(plan.outputConstraints.maxAddedGainDB) else {
            throw PlanValidationError.invalidOutputConstraint("maxAddedGainDB", plan.outputConstraints.maxAddedGainDB)
        }
        var ids = Set<UUID>()
        var addedGain = 0.0
        for node in plan.nodes {
            guard ids.insert(node.id).inserted else { throw PlanValidationError.duplicateNodeID(node.id) }
            guard !node.enabled || Self.implementedNodeTypes.contains(node.type) else { throw PlanValidationError.unsupportedNode(node.type) }
            guard node.confidence.isFinite, (0...1).contains(node.confidence) else { throw PlanValidationError.invalidConfidence(node.confidence) }
            guard node.rationale.lengthOfBytes(using: .utf8) <= Self.maximumRationaleBytes else {
                throw PlanValidationError.rationaleTooLong(node.id)
            }
            let allowed = Self.allowedParameters[node.type, default: []]
            for (parameter, value) in node.parameters {
                guard allowed.contains(parameter) else { throw PlanValidationError.unsupportedParameter(node.type, parameter) }
                guard let range = Self.ranges[parameter], value.isFinite, range.contains(value) else {
                    throw PlanValidationError.parameterOutOfRange(parameter, value: value, allowed: Self.ranges[parameter] ?? 0...0)
                }
                // Drive controls bounded nonlinear waveshaping, not a free linear
                // gain stage. Count only explicit linear/makeup gains here; peak
                // safety is independently checked on the exact rendered graph.
                if node.enabled, [.gainDB, .makeupGainDB].contains(parameter), value > 0 {
                    addedGain += value
                }
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

    /// Adds the structural invariant required when a graph can become audible
    /// in a host. Offline component tests may validate isolated modules with
    /// `validate`, while previews, IPC commits, and AU activation use this gate.
    public func validateForRealtimeActivation(
        _ plan: ProcessingPlan,
        currentSnapshotID: UUID? = nil,
        basePlan: ProcessingPlan? = nil
    ) throws {
        try validate(plan, currentSnapshotID: currentSnapshotID, basePlan: basePlan)
        let audibleNodes = plan.nodes.filter { $0.enabled && $0.type != .meter }
        guard audibleNodes.isEmpty || audibleNodes.last?.type == .limiter else {
            throw PlanValidationError.missingFinalSafetyLimiter
        }
        if let limiter = audibleNodes.last {
            // The current zero-lookahead limiter enforces sample peak. Requiring
            // its effective ceiling to be no looser than the declared preview
            // true-peak constraint prevents a live graph from intentionally
            // permitting a higher output ceiling than the plan it represents.
            // Exact dBTP is still measured on every captured preview; unseen
            // live material cannot be promised true-peak-safe without an
            // oversampled true-peak limiter.
            let ceilingDB = limiter.parameters[.ceilingDB, default: -1]
            guard ceilingDB <= plan.outputConstraints.maxTruePeakDB else {
                throw PlanValidationError.safetyLimiterCeilingExceedsConstraint(
                    ceilingDB: ceilingDB,
                    maxTruePeakDB: plan.outputConstraints.maxTruePeakDB
                )
            }
        }
    }
}
