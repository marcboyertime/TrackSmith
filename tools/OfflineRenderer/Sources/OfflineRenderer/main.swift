import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema

@main
enum OfflineRendererCommand {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            print("usage: OfflineRenderer input.wav processing-plan.json output.wav")
            throw Exit.failure
        }
        let input = try WAVFile.read(url: URL(fileURLWithPath: arguments[1]))
        let plan = try JSONDecoder().decode(ProcessingPlan.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[2])))
        var output = input
        var graph = try CompiledGraph(plan: plan, sampleRate: input.sampleRate, channelCount: input.channelCount)
        try graph.process(&output)
        try WAVFile.writeFloat32(output, url: URL(fileURLWithPath: arguments[3]))
        let report = AudioAnalyzer().analyze(output)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }
}

private enum Exit: Error { case failure }
