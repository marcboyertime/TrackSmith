import Foundation
import ProductionTutor

// Deterministic offline tutor corpus evaluation.
//
// Usage:
//   swift run ProductionTutorEvaluation [corpus.json] [--output report.json]
//
// The report contains typed case results (recognized issues, hypotheses,
// selected procedures, feedback transitions, forbidden-claim audit) and no
// raw audio. Exit code 1 when any case fails.

let arguments = CommandLine.arguments
var corpusPath = "research/evaluation/TRACKSMITH_TUTOR_INTENT_CORPUS_V1.json"
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
    let corpusData = try Data(contentsOf: URL(fileURLWithPath: corpusPath))
    let corpus = try JSONDecoder().decode(TutorCorpus.self, from: corpusData)
    let planner = try TutorPlanner()
    let harness = TutorEvaluationHarness(planner: planner)
    let report = harness.run(corpus)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let reportData = try encoder.encode(report)
    if let outputPath {
        try reportData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    for result in report.results where !result.passed {
        print("FAIL \(result.caseID)")
        for failure in result.failures {
            print("  - \(failure)")
        }
    }
    print("TUTOR_EVALUATION cases=\(report.caseCount) passed=\(report.passedCount)")
    exit(report.passedCount == report.caseCount ? 0 : 1)
} catch {
    FileHandle.standardError.write(Data("ProductionTutorEvaluation failed: \(error)\n".utf8))
    exit(2)
}
