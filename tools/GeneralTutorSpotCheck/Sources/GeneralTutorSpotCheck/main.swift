// Spot-check the acceptance-criteria questions end to end.
import Foundation
import ProductionTutor
import PlanSchema

let coordinator = try GeneralTutorCoordinator()

let checks: [(String, SourceType)] = [
    ("My MIDI piano does not line up with the tempo, but I do not want it robotic.", .keyboard),
    ("Why does my chorus feel smaller?", .fullMix),
    ("What should I try first?", .fullMix),
    ("What is pre-delay actually doing?", .vocal),
    ("Make me sound exactly like Billie Eilish.", .vocal),
]

for (question, source) in checks {
    let outcome = try coordinator.answer(
        GeneralTutorRequest(question: question, sourceType: source, explanationDepth: .standard)
    )
    let a = outcome.answer
    print("Q: \(question)")
    print("  kind=\(a.questionKind.rawValue) mode=\(a.answerMode.rawValue) confidence=\(a.confidenceClass.rawValue)")
    print("  domains=\(a.domains.prefix(4).map(\.rawValue))")
    print("  ANSWER: \(a.directAnswer.prefix(200))")
    if let first = a.recommendedFirstMove { print("  FIRST MOVE: \(first.prefix(180))") }
    print("  options=\(a.strategyOptions.count) claims=\(a.knowledgeClaimIDs.count) sources=\(a.sourceIDs.count) contradictions=\(a.contradictionIDs.count)")
    print("  audio: \(a.audioInfluence.statement.prefix(120))")
    if let t = a.teachingPrinciple { print("  PRINCIPLE: \(t.prefix(160))") }
    if !a.unsupportedCapabilities.isEmpty { print("  UNSUPPORTED: \(a.unsupportedCapabilities)") }
    print("")
}
