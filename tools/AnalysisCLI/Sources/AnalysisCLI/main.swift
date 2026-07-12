import AudioAnalysis
import DSPCore
import Foundation

@main
enum AnalysisCommand {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { print("usage: AnalysisCLI input.wav"); throw Exit.failure }
        let buffer = try WAVFile.read(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let report = AudioAnalyzer().analyze(buffer)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }
}

private enum Exit: Error { case failure }
