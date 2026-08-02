import AudioAnalysis
import CryptoKit
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer

private struct FixtureSpecification {
    var identifier: String
    var sourceFile: String
    var sourceType: SourceType
    var tailSeconds: Double
    var node: ProcessingNode
    var intendedComparison: String
    var preservationBoundary: String
}

private struct ArtifactRecord: Codable {
    var path: String
    var sha256: String
    var role: String
}

private struct FixtureRecord: Codable {
    var identifier: String
    var processor: String
    var algorithmVersion: Double
    var sourceFixture: String
    var sourceInputSHA256: String
    var sourceInputUnchanged: Bool
    var sourceArtifact: ArtifactRecord
    var candidateArtifact: ArtifactRecord
    var planArtifact: ArtifactRecord
    var analysisArtifact: ArtifactRecord
    var intendedComparison: String
    var preservationBoundary: String
    var loudnessMatchGainDB: Double
    var loudnessMatchMethod: String
    var difference: PreviewDifferenceMetrics
    var status: String
    var rejectionReasons: [String]
    var warnings: [String]
    var subjectivePreferenceRecorded: Bool
}

private struct FixtureManifest: Codable {
    var schemaVersion: String
    var suiteVersion: String
    var generatedAt: String
    var claimBoundary: [String: Bool]
    var sourceSuiteManifest: ArtifactRecord
    var fixtures: [FixtureRecord]
}

@main
private enum ProductionMasteryDSPFixtures {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            FileHandle.standardError.write(
                Data("usage: ProductionMasteryDSPFixtures source-suite-directory output-directory\n".utf8)
            )
            throw Exit.failure
        }
        let sourceRoot = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let outputRoot = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let sourceManifestURL = sourceRoot.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: sourceManifestURL.path) else {
            throw FixtureFailure.message("source suite manifest is missing: \(sourceManifestURL.path)")
        }
        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )

        let specifications = makeSpecifications()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Silence is represented as negative-infinity loudness by the analyzer.
        // Preserve that measurement explicitly instead of inventing a numeric floor.
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        var records: [FixtureRecord] = []
        let renderer = PreviewRenderer()

        for specification in specifications {
            let sourceURL = sourceRoot.appendingPathComponent(specification.sourceFile)
            let sourceHashBefore = try sha256(sourceURL)
            let source = try WAVFile.read(url: sourceURL)
            let auditionSource = appendSilence(source, seconds: specification.tailSeconds)
            let scope = ProcessingScope(
                kind: .importedFile,
                channelFormat: auditionSource.channelCount == 1 ? .mono : .stereo,
                sourceType: specification.sourceType
            )
            let limiter = ProcessingNode(
                id: stableUUID("\(specification.identifier)-limiter"),
                type: .limiter,
                parameters: [.ceilingDB: -3, .releaseMS: 80, .lookaheadMS: 0],
                rationale: "Retain inter-sample margin while candidate loudness is matched.",
                confidence: 1,
                category: .loudness
            )
            let plan = ProcessingPlan(
                requestID: stableUUID("\(specification.identifier)-request"),
                sourceSnapshotID: stableUUID("\(specification.identifier)-source"),
                scope: scope,
                goals: [],
                nodes: [specification.node, limiter],
                outputConstraints: .init(
                    maxTruePeakDB: -3,
                    loudnessMatchPreview: true,
                    preserveMonoCompatibility: true,
                    maxAddedGainDB: 6
                )
            )
            let rendered = try renderer.render(plan: plan, source: auditionSource)

            let sourceArtifactURL = outputRoot.appendingPathComponent(
                "\(specification.identifier)-source.wav"
            )
            let candidateURL = outputRoot.appendingPathComponent(
                "\(specification.identifier)-candidate.wav"
            )
            let planURL = outputRoot.appendingPathComponent(
                "\(specification.identifier)-plan.json"
            )
            let analysisURL = outputRoot.appendingPathComponent(
                "\(specification.identifier)-analysis.json"
            )
            try WAVFile.writeFloat32(auditionSource, url: sourceArtifactURL)
            try WAVFile.writeFloat32(rendered.audio, url: candidateURL)
            try encoder.encode(rendered.plan).write(to: planURL, options: .atomic)
            try encoder.encode(rendered.analysis).write(to: analysisURL, options: .atomic)

            let sourceHashAfter = try sha256(sourceURL)
            records.append(
                FixtureRecord(
                    identifier: specification.identifier,
                    processor: specification.node.type.rawValue,
                    algorithmVersion: specification.node.parameters[.algorithmVersion, default: 0],
                    sourceFixture: specification.sourceFile,
                    sourceInputSHA256: sourceHashBefore,
                    sourceInputUnchanged: sourceHashBefore == sourceHashAfter,
                    sourceArtifact: try artifact(sourceArtifactURL, relativeTo: outputRoot, role: "level-match reference with rendered-tail allowance"),
                    candidateArtifact: try artifact(candidateURL, relativeTo: outputRoot, role: "exact validator-gated level-matched candidate"),
                    planArtifact: try artifact(planURL, relativeTo: outputRoot, role: "exact committed processing graph"),
                    analysisArtifact: try artifact(analysisURL, relativeTo: outputRoot, role: "objective guardrail measurements"),
                    intendedComparison: specification.intendedComparison,
                    preservationBoundary: specification.preservationBoundary,
                    loudnessMatchGainDB: rendered.loudnessMatchGainDB,
                    loudnessMatchMethod: rendered.loudnessMatchMethod.rawValue,
                    difference: rendered.difference,
                    status: rendered.status.rawValue,
                    rejectionReasons: rendered.rejectionReasons,
                    warnings: rendered.warnings,
                    subjectivePreferenceRecorded: false
                )
            )
        }

        let manifest = FixtureManifest(
            schemaVersion: "1.0",
            suiteVersion: "tracksmith-production-mastery-dsp-listening-v1",
            generatedAt: "2026-07-27",
            claimBoundary: [
                "objectiveMetricsProveArtisticSuperiority": false,
                "syntheticFixturesAreHumanEvidence": false,
                "logicAlgorithmEquivalenceClaimed": false,
                "subjectivePreferenceRecorded": false,
            ],
            sourceSuiteManifest: try artifact(
                sourceManifestURL,
                relativeTo: sourceRoot,
                role: "deterministic PCM24 source-suite identity"
            ),
            fixtures: records
        )
        let manifestURL = outputRoot.appendingPathComponent("manifest.json")
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        print("wrote \(records.count) source/candidate pairs to \(outputRoot.path)")
    }

    private static func makeSpecifications() -> [FixtureSpecification] {
        [
            .init(
                identifier: "expander-gentle-vocal",
                sourceFile: "vocal_like_mono.wav",
                sourceType: .vocal,
                tailSeconds: 1,
                node: .init(
                    id: stableUUID("expander-gentle-vocal-node"),
                    type: .expander,
                    parameters: [
                        .algorithmVersion: 1, .thresholdDB: -48, .ratio: 2,
                        .attackMS: 4, .releaseMS: 180, .holdMS: 90,
                        .hysteresisDB: 6, .rangeDB: 14, .mix: 1,
                    ],
                    rationale: "Reduce inter-phrase noise gently while protecting word tails.",
                    confidence: 0.65,
                    category: .corrective
                ),
                intendedComparison: "Does gentle expansion lower gaps without shortening phrase endings or breath timing?",
                preservationBoundary: "Word tails, breaths, and direct-vocal tone remain listening-decisive."
            ),
            .init(
                identifier: "expander-firm-vocal",
                sourceFile: "vocal_like_mono.wav",
                sourceType: .vocal,
                tailSeconds: 1,
                node: .init(
                    id: stableUUID("expander-firm-vocal-node"),
                    type: .expander,
                    parameters: [
                        .algorithmVersion: 1, .thresholdDB: -38, .ratio: 5,
                        .attackMS: 2, .releaseMS: 120, .holdMS: 65,
                        .hysteresisDB: 8, .rangeDB: 30, .mix: 1,
                    ],
                    rationale: "Expose the preservation risk of a firmer bounded gate interpretation.",
                    confidence: 0.55,
                    category: .corrective
                ),
                intendedComparison: "Does stronger gap cleanup remain natural, or does it audibly truncate phrase detail?",
                preservationBoundary: "A cleaner metric cannot override audible tail loss or chatter."
            ),
            .init(
                identifier: "delay-slap-guitar",
                sourceFile: "guitar_like_dynamic_plucks_mono.wav",
                sourceType: .guitar,
                tailSeconds: 3,
                node: .init(
                    id: stableUUID("delay-slap-guitar-node"),
                    type: .delay,
                    parameters: [
                        .algorithmVersion: 1, .delayTimeMS: 92, .feedback: 0.08,
                        .damping: 0.4, .stereoCrossfeed: 0, .mix: 0.16,
                    ],
                    rationale: "Test a short discrete echo without claiming room simulation.",
                    confidence: 0.62,
                    category: .creative
                ),
                intendedComparison: "Does the short echo add dimension while preserving pick articulation?",
                preservationBoundary: "Pick attack, rhythmic precision, and unchanged dry source are protected."
            ),
            .init(
                identifier: "delay-rhythmic-guitar",
                sourceFile: "guitar_like_dynamic_plucks_mono.wav",
                sourceType: .guitar,
                tailSeconds: 5,
                node: .init(
                    id: stableUUID("delay-rhythmic-guitar-node"),
                    type: .delay,
                    parameters: [
                        .algorithmVersion: 1, .delayTimeMS: 250, .feedback: 0.34,
                        .damping: 0.55, .stereoCrossfeed: 0, .mix: 0.2,
                    ],
                    rationale: "Test audible rhythmic repeats with bounded decay and filtering.",
                    confidence: 0.58,
                    category: .creative
                ),
                intendedComparison: "Are the repeats musically supportive rather than masking the next pluck?",
                preservationBoundary: "Tempo intent is external context; this free-time fixture proves no sync claim."
            ),
            .init(
                identifier: "reverb-short-drum-room",
                sourceFile: "deterministic_noise_bursts_mono.wav",
                sourceType: .drums,
                tailSeconds: 3,
                node: .init(
                    id: stableUUID("reverb-short-drum-room-node"),
                    type: .reverb,
                    parameters: [
                        .algorithmVersion: 1, .preDelayMS: 24, .decayTimeSeconds: 0.55,
                        .roomSize: 0.35, .damping: 0.5, .diffusion: 0.62, .mix: 0.14,
                    ],
                    rationale: "Test a short room while retaining leading-edge focus.",
                    confidence: 0.6,
                    category: .creative
                ),
                intendedComparison: "Does the short room add space without pushing burst attacks backward?",
                preservationBoundary: "Attack focus and gap clarity are listening-decisive; bursts are not real drums."
            ),
            .init(
                identifier: "reverb-supporting-vocal",
                sourceFile: "vocal_like_mono.wav",
                sourceType: .vocal,
                tailSeconds: 5,
                node: .init(
                    id: stableUUID("reverb-supporting-vocal-node"),
                    type: .reverb,
                    parameters: [
                        .algorithmVersion: 1, .preDelayMS: 32, .decayTimeSeconds: 1.25,
                        .roomSize: 0.5, .damping: 0.55, .diffusion: 0.7, .mix: 0.13,
                    ],
                    rationale: "Test supporting ambience with direct consonants separated by predelay.",
                    confidence: 0.56,
                    category: .creative
                ),
                intendedComparison: "Does the ambience support the vocal without obscuring consonants or increasing perceived distance too far?",
                preservationBoundary: "Synthetic vocal-like material cannot establish real-vocal production quality."
            ),
        ]
    }

    private static func appendSilence(_ source: AudioBuffer, seconds: Double) -> AudioBuffer {
        let addedFrames = max(0, Int((seconds * source.sampleRate).rounded()))
        return AudioBuffer(
            channels: source.channels.map {
                $0 + Array(repeating: Float(0), count: addedFrames)
            },
            sampleRate: source.sampleRate
        )
    }

    private static func stableUUID(_ text: String) -> UUID {
        let digest = SHA256.hash(data: Data(text.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func sha256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func artifact(
        _ url: URL,
        relativeTo root: URL,
        role: String
    ) throws -> ArtifactRecord {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let relative = path.hasPrefix(rootPath + "/")
            ? String(path.dropFirst(rootPath.count + 1))
            : url.lastPathComponent
        return .init(path: relative, sha256: try sha256(url), role: role)
    }
}

private enum Exit: Error { case failure }

private enum FixtureFailure: Error {
    case message(String)
}
