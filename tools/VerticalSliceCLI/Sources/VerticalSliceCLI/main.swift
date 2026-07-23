import AgentCore
import AudioAnalysis
import CryptoKit
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer
import StateStore

private enum VerticalSliceError: Error, CustomStringConvertible {
    case missingInput
    case missingOptionValue(String)
    case unknownOption(String)
    case invalidSourceType(String)
    case emptyPrompt
    case sourceMissing(String)
    case outputAlreadyExists(String)
    case noBalancedPreview
    case noLockableNode
    case revisionDidNotTargetCompression

    var description: String {
        switch self {
        case .missingInput:
            "An external WAV path is required."
        case let .missingOptionValue(option):
            "Missing value for \(option)."
        case let .unknownOption(option):
            "Unknown option: \(option)."
        case let .invalidSourceType(value):
            "Unknown source type: \(value)."
        case .emptyPrompt:
            "The production request cannot be empty."
        case let .sourceMissing(path):
            "The external source does not exist: \(path)."
        case let .outputAlreadyExists(path):
            "The output directory already exists: \(path)."
        case .noBalancedPreview:
            "The balanced preview did not survive the safety and distinctness checks."
        case .noLockableNode:
            "The balanced graph contains no non-compressor node that can prove lock preservation."
        case .revisionDidNotTargetCompression:
            "The revision did not produce a measurable compression-only change."
        }
    }
}

private struct Options {
    var inputURL: URL
    var outputURL: URL
    var sourceType: SourceType = .vocal
    var prompt = "Make this clearer, warmer, and more controlled without sounding overprocessed"
    var revision = "Use less compression"

    static let usage = """
    usage: VerticalSliceCLI input.wav [--output evidence-directory]
                            [--source vocal|vocalBus|drums|drumBus|bass|guitar|keyboard|synth|fullMix|reference|unknown]
                            [--prompt "production request"]
                            [--revision "use less compression"]

    The source WAV is opened read-only and hashed before and after the run. The
    destination must not already exist. The bundle includes decoded dry comparison
    WAVs, but never modifies, moves, or overwrites the external source file.
    """

    init(arguments: [String]) throws {
        guard let input = arguments.first, !input.hasPrefix("--") else {
            throw VerticalSliceError.missingInput
        }
        inputURL = URL(fileURLWithPath: input).standardizedFileURL
        outputURL = Self.defaultOutputURL()

        var index = 1
        while index < arguments.count {
            let option = arguments[index]
            guard index + 1 < arguments.count else {
                throw VerticalSliceError.missingOptionValue(option)
            }
            let value = arguments[index + 1]
            switch option {
            case "--output":
                outputURL = URL(fileURLWithPath: value).standardizedFileURL
            case "--source":
                guard let parsed = SourceType(rawValue: value) else {
                    throw VerticalSliceError.invalidSourceType(value)
                }
                sourceType = parsed
            case "--prompt":
                prompt = value
            case "--revision":
                revision = value
            default:
                throw VerticalSliceError.unknownOption(option)
            }
            index += 2
        }

        prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        revision = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !revision.isEmpty else { throw VerticalSliceError.emptyPrompt }
    }

    private static func defaultOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "logic-audio-vertical-slice-\(formatter.string(from: Date()))"
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(name, isDirectory: true)
    }
}

private struct CheckEvidence: Codable {
    var identifier: String
    var passed: Bool
    var detail: String
}

private struct ArtifactEvidence: Codable {
    var relativePath: String
    var sha256: String
    var bytes: Int
}

private struct PreviewEvidence: Codable {
    var strength: PreviewStrength
    var previewID: UUID
    var status: PreviewStatus
    var audioFile: String?
    var planFile: String
    var analysisFile: String
    var loudnessMatchGainDB: Double
    var loudnessMatchMethod: LoudnessMatchMethod
    var differenceFromSource: PreviewDifferenceMetrics
    var differenceFromPreviousAudition: PreviewDifferenceMetrics
    var rejectionReasons: [String]
    var warnings: [String]
    var metrics: [String: Double]
    var plan: ProcessingPlan
}

private struct RevisionEvidence: Codable {
    var request: String
    var lockedNodeIDs: [UUID]
    var unmentionedNodesPreserved: Bool
    var lockedNodesPreserved: Bool
    var compressionChanged: Bool
    var previewStatus: PreviewStatus
    var previewDifference: PreviewDifferenceMetrics
    var selectedPlan: ProcessingPlan
    var revisedPlan: ProcessingPlan
    var revisedMetrics: [String: Double]
}

private struct SnapshotEvidence: Codable {
    var rootSnapshotID: UUID
    var balancedSnapshotID: UUID
    var revisedSnapshotID: UUID
    var undoRevisionReturnedID: UUID
    var undoToDryReturnedID: UUID
    var redoBalancedReturnedID: UUID
    var redoRevisionReturnedID: UUID
    var undoBalancedAudioMatched: Bool
    var undoDrySamplesMatchedSource: Bool
    var redoBalancedAudioMatched: Bool
    var redoRevisionAudioMatched: Bool
}

private struct BypassEvidence: Codable {
    var plan: ProcessingPlan
    var sampleExactAgainstDecodedSource: Bool
    var outputFile: String
    var outputMetrics: [String: Double]
}

private struct IntegrationEvidence: Codable {
    var executionMode: String
    var liveAudioUnitCommitProven: Bool
    var notes: [String]
}

private struct VerticalSliceEvidence: Codable {
    var schemaVersion: String
    var createdAt: Date
    var toolVersion: String
    var sourceFileName: String
    var sourcePathRedacted: Bool
    var sourceSHA256Before: String
    var sourceSHA256After: String
    var sourceWasUnmodified: Bool
    var sampleRate: Double
    var channelCount: Int
    var frameCount: Int
    var durationSeconds: Double
    var sourceType: SourceType
    var prompt: String
    var sourceAnalysisFile: String
    var sourceMetrics: [String: Double]
    var previews: [PreviewEvidence]
    var selectedStrength: PreviewStrength
    var balancedAppliedFile: String
    var balancedAppliedMetrics: [String: Double]
    var balancedRenderWasDeterministic: Bool
    var revision: RevisionEvidence
    var revisionRenderWasDeterministic: Bool
    var bypass: BypassEvidence
    var snapshots: SnapshotEvidence
    var integration: IntegrationEvidence
    var artifacts: [ArtifactEvidence]
    var checks: [CheckEvidence]
    var overallPassed: Bool
}

private struct EvaluatedVariant {
    var variant: PlanVariant
    var preview: RenderedPreview
    var pairwiseDifference: PreviewDifferenceMetrics
    var status: PreviewStatus
    var rejectionReasons: [String]
    var audioRelativePath: String?
    var planRelativePath: String
    var analysisRelativePath: String
}

@main
private enum VerticalSliceCommand {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] || arguments == ["-h"] {
            print(Options.usage)
            return
        }

        do {
            let options = try Options(arguments: arguments)
            let passed = try await run(options)
            if !passed { exit(1) }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n\n\(Options.usage)\n".utf8))
            exit(2)
        }
    }

    private static func run(_ options: Options) async throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.isReadableFile(atPath: options.inputURL.path) else {
            throw VerticalSliceError.sourceMissing(options.inputURL.path)
        }
        guard !fileManager.fileExists(atPath: options.outputURL.path) else {
            throw VerticalSliceError.outputAlreadyExists(options.outputURL.path)
        }

        let sourceHashBefore = try sha256File(options.inputURL)
        let source = try WAVFile.read(url: options.inputURL)
        let sourceAnalysis = AudioAnalyzer().analyze(source)
        let snapshotID = UUID()
        let scope = ProcessingScope(
            kind: .importedFile,
            channelFormat: source.channelCount == 1 ? .mono : .stereo,
            sourceType: options.sourceType,
            timeRangeSeconds: .init(
                start: 0,
                end: Double(source.frameCount) / source.sampleRate
            )
        )

        let parent = options.outputURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(
            "\(options.outputURL.lastPathComponent)-staging-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        var published = false
        defer { if !published { try? fileManager.removeItem(at: staging) } }

        let audioDirectory = staging.appendingPathComponent("audio", isDirectory: true)
        let analysisDirectory = staging.appendingPathComponent("analysis", isDirectory: true)
        let planDirectory = staging.appendingPathComponent("plans", isDirectory: true)
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: analysisDirectory, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: planDirectory, withIntermediateDirectories: false)

        let encoder = makeEncoder()
        let sourceAnalysisPath = "analysis/source.json"
        try writeJSON(sourceAnalysis, to: staging.appendingPathComponent(sourceAnalysisPath), encoder: encoder)

        let planner = DeterministicPlanner()
        let renderer = PreviewRenderer()
        let variants = try planner.variants(
            prompt: options.prompt,
            sourceSnapshotID: snapshotID,
            scope: scope,
            analysis: sourceAnalysis
        )
        var evaluated: [EvaluatedVariant] = []
        var previousAudition = source
        var acceptedVariantAudio: [AudioBuffer] = []
        let pairwiseDifferenceFloorDBFS = (sourceAnalysis.metrics["rms_dbfs"]?.value ?? -6) - 40
        for (index, variant) in variants.enumerated() {
            let preview = try renderer.render(plan: variant.plan, source: source)
            let pairwise = try renderer.compare(reference: previousAudition, candidate: preview.audio)
            var status = preview.status
            var rejectionReasons = preview.rejectionReasons
            let collapsedTowardAcceptedVariant = try acceptedVariantAudio.contains { prior in
                try renderer.compare(reference: prior, candidate: preview.audio).differenceRMSDBFS
                    < pairwiseDifferenceFloorDBFS
            }
            if index > 0, collapsedTowardAcceptedVariant {
                status = .rejected
                rejectionReasons.append(
                    "This option collapsed toward another accepted strength after level matching."
                )
            }

            let prefix = String(format: "%02d", index + 1)
            let stem = "\(prefix)-\(variant.strength.rawValue)"
            let planRelativePath = "plans/\(stem).json"
            let analysisRelativePath = "analysis/\(stem).json"
            try writeJSON(preview.plan, to: staging.appendingPathComponent(planRelativePath), encoder: encoder)
            try writeJSON(preview.analysis, to: staging.appendingPathComponent(analysisRelativePath), encoder: encoder)

            var audioRelativePath: String?
            if status == .valid {
                audioRelativePath = "audio/\(stem).wav"
                try WAVFile.writeFloat32(preview.audio, url: staging.appendingPathComponent(audioRelativePath!))
                previousAudition = preview.audio
                acceptedVariantAudio.append(preview.audio)
            }
            evaluated.append(EvaluatedVariant(
                variant: variant,
                preview: preview,
                pairwiseDifference: pairwise,
                status: status,
                rejectionReasons: rejectionReasons,
                audioRelativePath: audioRelativePath,
                planRelativePath: planRelativePath,
                analysisRelativePath: analysisRelativePath
            ))
        }

        guard let balanced = evaluated.first(where: {
            $0.variant.strength == .balanced && $0.status == .valid
        }) else { throw VerticalSliceError.noBalancedPreview }

        // The selected plan is the exact graph auditioned by the user, including
        // its materialized level-match node. Changing only `locked` metadata does
        // not alter its DSP output.
        var lockedBalancedPlan = balanced.preview.plan
        guard let lockIndex = lockedBalancedPlan.nodes.firstIndex(where: {
            $0.type == .parametricEQ && !$0.locked
        }) ?? lockedBalancedPlan.nodes.firstIndex(where: {
            $0.type != .compressor && !$0.locked
        }) else { throw VerticalSliceError.noLockableNode }
        lockedBalancedPlan.nodes[lockIndex].locked = true
        try PlanValidator().validate(lockedBalancedPlan, currentSnapshotID: snapshotID)
        let lockedNodeIDs = lockedBalancedPlan.nodes.filter(\.locked).map(\.id)
        let lockedBalancedPlanPath = "plans/balanced-selected-locked.json"
        try writeJSON(
            lockedBalancedPlan,
            to: staging.appendingPathComponent(lockedBalancedPlanPath),
            encoder: encoder
        )

        let balancedApplied = try renderRaw(plan: lockedBalancedPlan, source: source)
        let balancedAppliedAgain = try renderRaw(plan: lockedBalancedPlan, source: source)
        let balancedDeterministic = balancedApplied == balancedAppliedAgain
        let balancedMatchedAudition = balancedApplied == balanced.preview.audio
        let balancedAppliedAnalysis = AudioAnalyzer().analyze(balancedApplied)
        let balancedAppliedPath = "audio/04-balanced-applied.wav"
        try WAVFile.writeFloat32(balancedApplied, url: staging.appendingPathComponent(balancedAppliedPath))
        try writeJSON(
            balancedAppliedAnalysis,
            to: staging.appendingPathComponent("analysis/04-balanced-applied.json"),
            encoder: encoder
        )

        let revisedIntentPlan = try PlanRevisionEngine().revise(
            lockedBalancedPlan,
            request: options.revision
        )
        // Upstream dynamics changed, so an unlocked, system-authored match is no
        // longer valid. Recalculate that one dependent node; all user/production
        // nodes outside compression remain byte-identical.
        var revisionRenderPlan = revisedIntentPlan
        revisionRenderPlan.nodes.removeAll { $0.type == .loudnessMatch && !$0.locked }
        let revisedPreview = try renderer.render(plan: revisionRenderPlan, source: source)
        let revisedPlan = revisedPreview.plan
        let unmentionedBefore = lockedBalancedPlan.nodes.filter {
            $0.type != .compressor && $0.type != .loudnessMatch
        }
        let unmentionedAfter = revisedPlan.nodes.filter {
            $0.type != .compressor && $0.type != .loudnessMatch
        }
        let unmentionedPreserved = unmentionedBefore == unmentionedAfter
        let lockedPreserved = lockedBalancedPlan.nodes.filter(\.locked).allSatisfy { lockedNode in
            revisedPlan.nodes.first(where: { $0.id == lockedNode.id }) == lockedNode
        }
        let compressionChanged = try compressionWasTargeted(
            before: lockedBalancedPlan,
            after: revisedPlan,
            request: options.revision
        )
        guard compressionChanged else { throw VerticalSliceError.revisionDidNotTargetCompression }

        let revisedPlanPath = "plans/revised.json"
        try writeJSON(revisedPlan, to: staging.appendingPathComponent(revisedPlanPath), encoder: encoder)
        if revisedPreview.status == .valid {
            try WAVFile.writeFloat32(
                revisedPreview.audio,
                url: staging.appendingPathComponent("audio/05-revised-preview.wav")
            )
        }
        try writeJSON(
            revisedPreview.analysis,
            to: staging.appendingPathComponent("analysis/05-revised-preview.json"),
            encoder: encoder
        )
        let revisedApplied = try renderRaw(plan: revisedPlan, source: source)
        let revisedAppliedAgain = try renderRaw(plan: revisedPlan, source: source)
        let revisedDeterministic = revisedApplied == revisedAppliedAgain
        let revisedMatchedAudition = revisedApplied == revisedPreview.audio
        let revisedAppliedAnalysis = AudioAnalyzer().analyze(revisedApplied)
        try WAVFile.writeFloat32(
            revisedApplied,
            url: staging.appendingPathComponent("audio/06-revised-applied.wav")
        )
        try writeJSON(
            revisedAppliedAnalysis,
            to: staging.appendingPathComponent("analysis/06-revised-applied.json"),
            encoder: encoder
        )

        let dryPlan = ProcessingPlan(
            sourceSnapshotID: snapshotID,
            scope: scope,
            goals: [],
            nodes: []
        )
        try PlanValidator().validate(dryPlan, currentSnapshotID: snapshotID)
        try writeJSON(dryPlan, to: staging.appendingPathComponent("plans/dry-bypass.json"), encoder: encoder)
        let bypassAudio = try renderRaw(plan: dryPlan, source: source)
        let bypassExact = bypassAudio == source
        let bypassAnalysis = AudioAnalyzer().analyze(bypassAudio)
        let bypassPath = "audio/07-dry-bypass.wav"
        try WAVFile.writeFloat32(bypassAudio, url: staging.appendingPathComponent(bypassPath))
        try writeJSON(
            bypassAnalysis,
            to: staging.appendingPathComponent("analysis/07-dry-bypass.json"),
            encoder: encoder
        )

        let store = SnapshotStore()
        let rootSnapshot = ProcessingSnapshot(
            parentID: nil,
            plan: dryPlan,
            analysisVersion: sourceAnalysis.version,
            sourceIdentity: sourceHashBefore,
            sourceContentHash: sourceHashBefore,
            structuredGoals: [],
            pluginVersion: "offline-public-api",
            commitStatus: .committed
        )
        let balancedSnapshot = ProcessingSnapshot(
            parentID: rootSnapshot.id,
            plan: lockedBalancedPlan,
            analysisVersion: sourceAnalysis.version,
            sourceIdentity: sourceHashBefore,
            sourceContentHash: sourceHashBefore,
            structuredGoals: lockedBalancedPlan.goals,
            previewReferences: evaluated.map { $0.preview.id },
            pluginVersion: "offline-public-api",
            commitStatus: .committed
        )
        let revisedSnapshot = ProcessingSnapshot(
            parentID: balancedSnapshot.id,
            plan: revisedPlan,
            analysisVersion: sourceAnalysis.version,
            sourceIdentity: sourceHashBefore,
            sourceContentHash: sourceHashBefore,
            structuredGoals: revisedPlan.goals,
            previewReferences: [revisedPreview.id],
            pluginVersion: "offline-public-api",
            commitStatus: .proposed
        )
        await store.add(rootSnapshot)
        await store.add(balancedSnapshot)
        await store.add(revisedSnapshot)
        try await store.commit(id: revisedSnapshot.id)

        let undoRevision = try await store.undo()
        let undoBalancedAudio = try renderRaw(plan: undoRevision.plan, source: source)
        let undoBalancedMatched = undoBalancedAudio == balancedApplied
        try WAVFile.writeFloat32(
            undoBalancedAudio,
            url: staging.appendingPathComponent("audio/08-undo-to-balanced.wav")
        )

        let undoToDry = try await store.undo()
        let undoDryAudio = try renderRaw(plan: undoToDry.plan, source: source)
        let undoDryMatched = undoDryAudio == source
        try WAVFile.writeFloat32(
            undoDryAudio,
            url: staging.appendingPathComponent("audio/09-undo-to-dry.wav")
        )

        let redoBalanced = try await store.redo()
        let redoBalancedAudio = try renderRaw(plan: redoBalanced.plan, source: source)
        let redoBalancedMatched = redoBalancedAudio == balancedApplied
        try WAVFile.writeFloat32(
            redoBalancedAudio,
            url: staging.appendingPathComponent("audio/10-redo-balanced.wav")
        )

        let redoRevision = try await store.redo()
        let redoRevisionAudio = try renderRaw(plan: redoRevision.plan, source: source)
        let redoRevisionMatched = redoRevisionAudio == revisedApplied
        try WAVFile.writeFloat32(
            redoRevisionAudio,
            url: staging.appendingPathComponent("audio/11-redo-revised.wav")
        )

        let sourceHashAfter = try sha256File(options.inputURL)
        let sourceUnmodified = sourceHashBefore == sourceHashAfter
        let validCount = evaluated.filter { $0.status == .valid }.count
        let strengthsComplete = evaluated.map(\EvaluatedVariant.variant.strength) == PreviewStrength.allCases
        let previewsMatchPersistedPlans = try evaluated.allSatisfy { item in
            try renderRaw(plan: item.preview.plan, source: source) == item.preview.audio
        }
        let acceptedPreviews = evaluated.filter { $0.status == .valid }
        var pairwiseDistinct = true
        for firstIndex in acceptedPreviews.indices {
            for secondIndex in acceptedPreviews.indices where secondIndex > firstIndex {
                let difference = try renderer.compare(
                    reference: acceptedPreviews[firstIndex].preview.audio,
                    candidate: acceptedPreviews[secondIndex].preview.audio
                )
                if difference.differenceRMSDBFS < pairwiseDifferenceFloorDBFS { pairwiseDistinct = false }
            }
        }

        var checks = [
            CheckEvidence(identifier: "source_hash_stable", passed: sourceUnmodified, detail: "External source SHA-256 matches before and after the run."),
            CheckEvidence(identifier: "three_strengths_rendered", passed: strengthsComplete, detail: "Conservative, balanced, and strong plans were rendered in order."),
            CheckEvidence(identifier: "three_previews_valid", passed: validCount == 3, detail: "\(validCount) of 3 preview variants survived safety checks."),
            CheckEvidence(identifier: "preview_strengths_distinct", passed: pairwiseDistinct, detail: "Every pair of accepted strengths passed the bounded audio-difference gate."),
            CheckEvidence(identifier: "balanced_render_deterministic", passed: balancedDeterministic, detail: "Two fresh balanced graph renders are sample-identical."),
            CheckEvidence(identifier: "balanced_selection_matches_audition", passed: balancedMatchedAudition, detail: "The selected saved graph reproduces the balanced audition sample-for-sample."),
            CheckEvidence(identifier: "preview_graphs_match_auditions", passed: previewsMatchPersistedPlans, detail: "Every audition is a fresh render of its saved graph."),
            CheckEvidence(identifier: "revision_unmentioned_nodes_preserved", passed: unmentionedPreserved, detail: "Production nodes outside compression are byte-for-byte equivalent; only the dependent unlocked level-match node is recalculated."),
            CheckEvidence(identifier: "revision_locked_nodes_preserved", passed: lockedPreserved, detail: "Every locked node remains present and unchanged."),
            CheckEvidence(identifier: "revision_targeted_compression", passed: compressionChanged, detail: "Compression was the only user-authored production change; the dependent unlocked level-match node was recalculated."),
            CheckEvidence(identifier: "revision_preview_safe", passed: revisedPreview.status == .valid, detail: revisedPreview.rejectionReasons.joined(separator: "; ").nonEmpty ?? "Revision preview passed constraints."),
            CheckEvidence(identifier: "revision_render_deterministic", passed: revisedDeterministic, detail: "Two fresh revised graph renders are sample-identical."),
            CheckEvidence(identifier: "revision_saved_graph_matches_audition", passed: revisedMatchedAudition, detail: "The revised saved graph reproduces its audition sample-for-sample."),
            CheckEvidence(identifier: "dry_bypass_sample_exact", passed: bypassExact, detail: "The empty graph preserves every decoded source sample."),
            CheckEvidence(identifier: "snapshot_undo_revision", passed: undoRevision.id == balancedSnapshot.id && undoBalancedMatched, detail: "Undo returned the balanced parent and reproduced its audio."),
            CheckEvidence(identifier: "snapshot_undo_to_dry", passed: undoToDry.id == rootSnapshot.id && undoDryMatched, detail: "Second undo returned the dry root and reproduced source samples."),
            CheckEvidence(identifier: "snapshot_redo_balanced", passed: redoBalanced.id == balancedSnapshot.id && redoBalancedMatched, detail: "Redo returned and reproduced the balanced snapshot."),
            CheckEvidence(identifier: "snapshot_redo_revision", passed: redoRevision.id == revisedSnapshot.id && redoRevisionMatched, detail: "Second redo returned and reproduced the revised snapshot."),
        ]
        checks.sort { $0.identifier < $1.identifier }
        let overallPassed = checks.allSatisfy(\.passed)

        let previewEvidence = evaluated.map { item in
            PreviewEvidence(
                strength: item.variant.strength,
                previewID: item.preview.id,
                status: item.status,
                audioFile: item.audioRelativePath,
                planFile: item.planRelativePath,
                analysisFile: item.analysisRelativePath,
                loudnessMatchGainDB: item.preview.loudnessMatchGainDB,
                loudnessMatchMethod: item.preview.loudnessMatchMethod,
                differenceFromSource: item.preview.difference,
                differenceFromPreviousAudition: item.pairwiseDifference,
                rejectionReasons: item.rejectionReasons,
                warnings: item.preview.warnings,
                metrics: scalarMetrics(item.preview.analysis),
                plan: item.preview.plan
            )
        }
        let revisionEvidence = RevisionEvidence(
            request: options.revision,
            lockedNodeIDs: lockedNodeIDs,
            unmentionedNodesPreserved: unmentionedPreserved,
            lockedNodesPreserved: lockedPreserved,
            compressionChanged: compressionChanged,
            previewStatus: revisedPreview.status,
            previewDifference: revisedPreview.difference,
            selectedPlan: lockedBalancedPlan,
            revisedPlan: revisedPlan,
            revisedMetrics: scalarMetrics(revisedAppliedAnalysis)
        )
        let snapshotEvidence = SnapshotEvidence(
            rootSnapshotID: rootSnapshot.id,
            balancedSnapshotID: balancedSnapshot.id,
            revisedSnapshotID: revisedSnapshot.id,
            undoRevisionReturnedID: undoRevision.id,
            undoToDryReturnedID: undoToDry.id,
            redoBalancedReturnedID: redoBalanced.id,
            redoRevisionReturnedID: redoRevision.id,
            undoBalancedAudioMatched: undoBalancedMatched,
            undoDrySamplesMatchedSource: undoDryMatched,
            redoBalancedAudioMatched: redoBalancedMatched,
            redoRevisionAudioMatched: redoRevisionMatched
        )
        let bypassEvidence = BypassEvidence(
            plan: dryPlan,
            sampleExactAgainstDecodedSource: bypassExact,
            outputFile: bypassPath,
            outputMetrics: scalarMetrics(bypassAnalysis)
        )
        let integration = IntegrationEvidence(
            executionMode: "offline public package APIs",
            liveAudioUnitCommitProven: false,
            notes: [
                "Applied outputs use the same public CompiledGraph used by the Audio Unit, but this target does not host or commit to AssistantAudioUnit.",
                "Add AudioUnitExtensionCore and SessionCore dependencies to extend this runner with live AU render, capture, App Group commit, and fullState restoration.",
                "SnapshotStore proves in-process typed undo/redo only; it is not persistent restart recovery."
            ]
        )

        let artifacts = try artifactEvidence(in: staging)
        let evidence = VerticalSliceEvidence(
            schemaVersion: "1.0",
            createdAt: Date(),
            toolVersion: "0.1.0",
            sourceFileName: options.inputURL.pathExtension.isEmpty
                ? "<redacted>"
                : "<redacted>.\(options.inputURL.pathExtension.lowercased())",
            sourcePathRedacted: true,
            sourceSHA256Before: sourceHashBefore,
            sourceSHA256After: sourceHashAfter,
            sourceWasUnmodified: sourceUnmodified,
            sampleRate: source.sampleRate,
            channelCount: source.channelCount,
            frameCount: source.frameCount,
            durationSeconds: Double(source.frameCount) / source.sampleRate,
            sourceType: options.sourceType,
            prompt: options.prompt,
            sourceAnalysisFile: sourceAnalysisPath,
            sourceMetrics: scalarMetrics(sourceAnalysis),
            previews: previewEvidence,
            selectedStrength: .balanced,
            balancedAppliedFile: balancedAppliedPath,
            balancedAppliedMetrics: scalarMetrics(balancedAppliedAnalysis),
            balancedRenderWasDeterministic: balancedDeterministic,
            revision: revisionEvidence,
            revisionRenderWasDeterministic: revisedDeterministic,
            bypass: bypassEvidence,
            snapshots: snapshotEvidence,
            integration: integration,
            artifacts: artifacts,
            checks: checks,
            overallPassed: overallPassed
        )
        try writeJSON(evidence, to: staging.appendingPathComponent("evidence.json"), encoder: encoder)

        try fileManager.moveItem(at: staging, to: options.outputURL)
        published = true
        print(overallPassed ? "PASS real-audio offline vertical slice" : "FAIL one or more vertical-slice checks")
        print("evidence=\(options.outputURL.appendingPathComponent("evidence.json").path)")
        print("source_sha256=\(sourceHashBefore)")
        print("source_unmodified=\(sourceUnmodified)")
        print("valid_previews=\(validCount)")
        print("live_au_commit_proven=false")
        return overallPassed
    }

    private static func renderRaw(plan: ProcessingPlan, source: AudioBuffer) throws -> AudioBuffer {
        try PlanValidator().validate(plan, currentSnapshotID: plan.sourceSnapshotID)
        var output = source
        var graph = try CompiledGraph(
            plan: plan,
            sampleRate: source.sampleRate,
            channelCount: source.channelCount
        )
        try graph.process(&output)
        return output
    }

    private static func compressionWasTargeted(
        before: ProcessingPlan,
        after: ProcessingPlan,
        request: String
    ) throws -> Bool {
        let beforeCompressors = before.nodes.filter { $0.type == .compressor }
        let afterCompressors = after.nodes.filter { $0.type == .compressor }
        guard !beforeCompressors.isEmpty else { return false }
        let text = request.lowercased()
        if text.contains("undo") || text.contains("remove") {
            return afterCompressors.isEmpty
        }
        guard beforeCompressors.count == afterCompressors.count else { return false }
        return zip(beforeCompressors, afterCompressors).allSatisfy { old, new in
            old.id == new.id
                && new.parameters[.ratio, default: 1] < old.parameters[.ratio, default: 1]
                && new.parameters[.thresholdDB, default: -240] > old.parameters[.thresholdDB, default: -240]
        }
    }

    private static func scalarMetrics(_ report: AnalysisReport) -> [String: Double] {
        report.metrics.mapValues(\.value)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func writeJSON<T: Encodable>(
        _ value: T,
        to url: URL,
        encoder: JSONEncoder
    ) throws {
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func artifactEvidence(in root: URL) throws -> [ArtifactEvidence] {
        let fileManager = FileManager.default
        var result: [ArtifactEvidence] = []

        // Carry the relative path through recursion. Foundation may return
        // `/private/tmp/...` children while the caller supplied `/tmp/...`, so
        // deriving relative paths by subtracting absolute string prefixes is
        // not reliable on macOS.
        func visit(_ directory: URL, relativeDirectory: String) throws {
            for url in try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                let relativePath = relativeDirectory.isEmpty
                    ? url.lastPathComponent
                    : relativeDirectory + "/" + url.lastPathComponent
                if values.isDirectory == true {
                    try visit(url, relativeDirectory: relativePath)
                    continue
                }
                guard values.isRegularFile == true, url.lastPathComponent != "evidence.json" else { continue }
                result.append(ArtifactEvidence(
                    relativePath: relativePath,
                    sha256: try sha256File(url),
                    bytes: values.fileSize ?? 0
                ))
            }
        }

        try visit(root, relativeDirectory: "")
        return result.sorted { $0.relativePath < $1.relativePath }
    }

    private static func sha256File(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
