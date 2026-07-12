import AgentCore
import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer
import SharedIPC

@main
enum CompanionCommand {
    static func main() throws {
        if CommandLine.arguments.dropFirst().first == "--ipc-status" {
            let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LOGIC_ASSISTANT_EXCHANGE"] ?? "/tmp/logic-audio-assistant-exchange")
            let messages = try FileExchange(directory: directory).list()
            print("messages=\(messages.count)")
            for message in messages { print("\(message.kind.rawValue) \(message.id.uuidString) \(message.text ?? "")") }
            return
        }
        let prompt = CommandLine.arguments.dropFirst().joined(separator: " ").nonEmpty ?? "make this clearer and more controlled"
        let sampleRate = 48_000.0, frames = 48_000
        let signal = (0..<frames).map { frame -> Float in
            let time = Double(frame) / sampleRate
            return Float(0.22 * sin(2 * .pi * 220 * time) + 0.08 * sin(2 * .pi * 3_200 * time))
        }
        let source = AudioBuffer(channels: [signal], sampleRate: sampleRate)
        let analysis = AudioAnalyzer().analyze(source)
        let snapshotID = UUID()
        let scope = ProcessingScope(kind: .pluginInput, channelFormat: .mono, sourceType: .vocal, timeRangeSeconds: .init(start: 0, end: 1))
        let variants = try DeterministicPlanner().variants(prompt: prompt, sourceSnapshotID: snapshotID, scope: scope, analysis: analysis)
        let renderer = PreviewRenderer()
        print("request=\(prompt)")
        for variant in variants {
            let preview = try renderer.render(plan: variant.plan, source: source)
            print("\(variant.strength.rawValue): \(preview.status.rawValue), nodes=\(variant.plan.nodes.count), level_match_db=\(String(format: "%.2f", preview.loudnessMatchGainDB))")
            for node in variant.plan.nodes { print("  \(node.type.rawValue): \(node.rationale)") }
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
