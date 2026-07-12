import Foundation
import PlanSchema

public struct PlanRevisionEngine: Sendable {
    public init() {}

    public func revise(_ plan: ProcessingPlan, request: String) throws -> ProcessingPlan {
        let text = request.lowercased()
        var revised = plan
        if text.contains("less compression") || text.contains("less of that") {
            revised.nodes = revised.nodes.map { node in
                guard node.type == .compressor, !node.locked else { return node }
                var copy = node
                copy.parameters[.ratio] = 1 + (copy.parameters[.ratio, default: 2] - 1) * 0.6
                copy.parameters[.thresholdDB] = min(0, copy.parameters[.thresholdDB, default: -18] + 3)
                copy.rationale = "Compression reduced in response to the revision while preserving the remaining graph."
                return copy
            }
        } else if text.contains("undo") && text.contains("compression") || text.contains("remove the compression") {
            revised.nodes.removeAll { $0.type == .compressor && !$0.locked }
        } else if text.contains("lock") && text.contains("eq") {
            revised.nodes = revised.nodes.map { node in var copy = node; if node.type == .parametricEQ { copy.locked = true }; return copy }
        } else if text.contains("remove") && text.contains("reverb") || text.contains("less reverb") {
            revised.nodes = revised.nodes.compactMap { node in
                guard node.type == .reverb, !node.locked else { return node }
                if text.contains("less") { var copy = node; copy.parameters[.mix] = copy.parameters[.mix, default: 0.2] * 0.5; return copy }
                return nil
            }
        } else {
            throw PlannerError.unsupportedRequest("This deterministic revision is not implemented; no state was changed.")
        }
        revised.requestID = UUID()
        try PlanValidator().validate(revised, currentSnapshotID: plan.sourceSnapshotID, basePlan: plan)
        return revised
    }
}
