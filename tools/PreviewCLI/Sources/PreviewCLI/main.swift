import Foundation
import PlanSchema
import PreviewWorkflow

@main
enum PreviewCommand {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] || arguments == ["-h"] {
            print(Options.usage)
            return
        }
        do {
            let options = try Options(arguments: arguments)
            let result = try PreviewSessionExporter().export(
                inputURL: options.input,
                prompt: options.prompt,
                sourceType: options.sourceType,
                outputDirectory: options.output
            )
            print("Created \(result.manifest.validVariantCount) valid previews in:")
            print(result.directory.path)
            for variant in result.manifest.variants {
                let file = variant.audioFileName ?? "not written (rejected)"
                print("\(variant.strength.rawValue): \(variant.status.rawValue) — \(file)")
            }
            print("Details: \(result.directory.appendingPathComponent("AUDITION.txt").path)")
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n\n\(Options.usage)\n".utf8))
            exit(2)
        }
    }
}

private struct Options {
    var input: URL
    var prompt: String
    var sourceType: SourceType
    var output: URL

    static let usage = """
    usage: PreviewCLI input.wav --prompt "make this clearer and more controlled"
                      [--source vocal|vocalBus|drums|drumBus|bass|guitar|keyboard|synth|fullMix|reference|unknown]
                      [--output preview-directory]

    The output directory must not already exist. The input WAV is never modified.
    """

    init(arguments: [String]) throws {
        guard let first = arguments.first else { throw CLIError.missingInput }
        input = URL(fileURLWithPath: first)
        var promptValue: String?
        var source: SourceType = .unknown
        var outputValue: URL?
        var index = 1
        while index < arguments.count {
            let option = arguments[index]
            guard index + 1 < arguments.count else { throw CLIError.missingValue(option) }
            let value = arguments[index + 1]
            switch option {
            case "--prompt": promptValue = value
            case "--source":
                guard let parsed = SourceType(rawValue: value) else { throw CLIError.invalidSource(value) }
                source = parsed
            case "--output": outputValue = URL(fileURLWithPath: value)
            default: throw CLIError.unknownOption(option)
            }
            index += 2
        }
        guard let promptValue else { throw CLIError.missingPrompt }
        prompt = promptValue
        sourceType = source
        output = outputValue ?? Self.defaultOutput(for: input)
    }

    private static func defaultOutput(for input: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = input.deletingPathExtension().lastPathComponent + "-previews-" + formatter.string(from: Date())
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(name, isDirectory: true)
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case missingInput
    case missingPrompt
    case missingValue(String)
    case unknownOption(String)
    case invalidSource(String)

    var description: String {
        switch self {
        case .missingInput: "An input WAV path is required"
        case .missingPrompt: "--prompt is required"
        case let .missingValue(option): "Missing value for \(option)"
        case let .unknownOption(option): "Unknown option: \(option)"
        case let .invalidSource(value): "Unknown source type: \(value)"
        }
    }
}
