import Foundation
import ProductionTutor

// Deterministic offline evaluation of the open-domain production tutor.
//
// Usage:
//   swift run GeneralTutorEvaluation [corpus.json] [--output report.json]
//
// Exits nonzero when any case fails. The report contains routed domains,
// answer modes, citation counts, and validation outcomes — and no raw audio.

let arguments = CommandLine.arguments
var corpusPath = "research/evaluation/TRACKSMITH_GENERAL_TUTOR_CORPUS_V1.json"
var outputPath: String?
var index = 1
while index < arguments.count {
    let argument = arguments[index]
    if argument == "--output", index + 1 < arguments.count {
        outputPath = arguments[index + 1]
        index += 2
    } else {
        corpusPath = argument
        index += 1
    }
}

do {
    let data = try Data(contentsOf: URL(fileURLWithPath: corpusPath))
    let corpus = try JSONDecoder().decode(GeneralCorpus.self, from: data)
    let harness = try GeneralTutorEvaluationHarness()
    let report = harness.run(corpus)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    if let outputPath {
        try encoder.encode(report).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    var shown = 0
    for result in report.results where !result.passed {
        if shown < 15 {
            print("FAIL \(result.caseID)")
            for failure in result.failures { print("  - \(failure)") }
        }
        shown += 1
    }
    if shown > 15 { print("… and \(shown - 15) more failing cases") }

    print("GENERAL_TUTOR_EVALUATION cases=\(report.caseCount) passed=\(report.passedCount)")
    print("  domains=\(report.domainsExercised.count) kinds=\(report.questionKindsExercised.count)")
    print("  modes=\(report.answerModeCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
    exit(report.passedCount == report.caseCount ? 0 : 1)
} catch {
    FileHandle.standardError.write(Data("GeneralTutorEvaluation failed: \(error)\n".utf8))
    exit(2)
}
