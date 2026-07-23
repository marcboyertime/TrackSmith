import AgentCore
import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer

public enum PreviewExportError: Error, CustomStringConvertible, Sendable {
    case outputAlreadyExists(String)
    case emptyPrompt
    case noAudioFrames
    case invalidProductionCandidates(String)

    public var description: String {
        switch self {
        case let .outputAlreadyExists(path): "Output directory already exists: \(path)"
        case .emptyPrompt: "The production request cannot be empty."
        case .noAudioFrames: "The input WAV contains no audio frames."
        case let .invalidProductionCandidates(reason): "The production-intelligence candidates are invalid: \(reason)"
        }
    }
}

public struct PreviewVariantManifest: Codable, Sendable {
    public var strength: PreviewStrength
    public var previewID: UUID
    public var status: PreviewStatus
    public var audioFileName: String?
    public var planFileName: String
    public var loudnessMatchGainDB: Double
    public var loudnessMatchMethod: LoudnessMatchMethod
    public var difference: PreviewDifferenceMetrics
    public var pairwiseDifferenceFromPrevious: PreviewDifferenceMetrics?
    public var rejectionReasons: [String]
    public var warnings: [String]
    public var plan: ProcessingPlan
    public var analysis: AnalysisReport
    public var candidateIdentifier: String? = nil
    public var hypothesisIdentifier: String? = nil
    public var candidateSummary: String? = nil
}

public struct PreviewSessionManifest: Codable, Sendable {
    public var schemaVersion: String
    public var createdAt: Date
    public var inputFileName: String
    public var sourceFingerprint: String
    public var prompt: String
    public var sourceType: SourceType
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int
    public var durationSeconds: Double
    public var sourceSnapshotID: UUID
    public var originalAudioFileName: String
    public var originalAnalysis: AnalysisReport
    public var variants: [PreviewVariantManifest]
    public var productionIntentResult: ProductionIntentResult? = nil
    public var providerMetadata: ProviderExecutionMetadata? = nil

    public var validVariantCount: Int { variants.count { $0.status == .valid } }
}

public struct PreviewExportResult: Sendable {
    public var directory: URL
    public var manifest: PreviewSessionManifest
}

/// One immutable audition artifact for an edit of the current working plan.
/// Revisions live beside, rather than overwrite, the original three-option
/// preview session so a failed or cancelled edit cannot invalidate prior A/Bs.
public struct WorkingPlanPreviewResult: Sendable {
    public var directory: URL
    public var variant: PreviewVariantManifest

    public var audioURL: URL? {
        variant.audioFileName.map { directory.appendingPathComponent($0) }
    }

    public var planURL: URL {
        directory.appendingPathComponent(variant.planFileName)
    }
}

public struct PreviewSessionExporter: Sendable {
    public init() {}

    /// Applies only the narrowly bounded conversational edits supported by the
    /// deterministic revision engine. The engine validates locked-node and
    /// source-snapshot invariants before this method returns.
    public func revise(plan: ProcessingPlan, request: String) throws -> ProcessingPlan {
        try PlanRevisionEngine().revise(plan, request: request)
    }

    /// Renders a candidate working graph into a new immutable subdirectory.
    /// The source and all earlier previews are read-only. An unlocked,
    /// system-authored loudness-match node is recalculated because changing an
    /// upstream node invalidates its old measured compensation; a user-locked
    /// loudness-match node is preserved exactly.
    public func renderWorkingPlan(
        inputURL: URL,
        plan: ProcessingPlan,
        outputDirectory: URL
    ) throws -> WorkingPlanPreviewResult {
        let source = try WAVFile.read(url: inputURL)
        guard source.frameCount > 0 else { throw PreviewExportError.noAudioFrames }
        try PlanValidator().validate(plan)

        var renderPlan = plan
        let hasDisabledLoudnessMatch = renderPlan.nodes.contains {
            $0.type == .loudnessMatch && !$0.enabled
        }
        let hasLockedLoudnessMatch = renderPlan.nodes.contains {
            $0.type == .loudnessMatch && $0.locked
        }
        if hasDisabledLoudnessMatch {
            // A per-node bypass is an explicit user decision. Prevent the
            // renderer from interpreting the missing enabled stage as a request
            // to synthesize a replacement loudness-match node.
            renderPlan.outputConstraints.loudnessMatchPreview = false
        } else if !hasLockedLoudnessMatch {
            renderPlan.nodes.removeAll { $0.type == .loudnessMatch }
        }
        let preview = try PreviewRenderer().render(plan: renderPlan, source: source)

        let fileManager = FileManager.default
        let revisionsRoot = outputDirectory.standardizedFileURL
            .appendingPathComponent("working-revisions", isDirectory: true)
        try fileManager.createDirectory(at: revisionsRoot, withIntermediateDirectories: true)

        let directoryName = preview.id.uuidString.lowercased()
        let destination = revisionsRoot.appendingPathComponent(directoryName, isDirectory: true)
        let staging = revisionsRoot.appendingPathComponent(
            "\(directoryName)-staging-\(UUID().uuidString.lowercased())",
            isDirectory: true
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        var published = false
        defer { if !published { try? fileManager.removeItem(at: staging) } }

        let audioFileName = preview.status == .valid ? "preview.wav" : nil
        if let audioFileName {
            try WAVFile.writeFloat32(preview.audio, url: staging.appendingPathComponent(audioFileName))
        }
        let planFileName = "plan.json"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(preview.plan).write(
            to: staging.appendingPathComponent(planFileName),
            options: .atomic
        )

        let variant = PreviewVariantManifest(
            strength: .balanced,
            previewID: preview.id,
            status: preview.status,
            audioFileName: audioFileName,
            planFileName: planFileName,
            loudnessMatchGainDB: preview.loudnessMatchGainDB,
            loudnessMatchMethod: preview.loudnessMatchMethod,
            difference: preview.difference,
            pairwiseDifferenceFromPrevious: preview.difference,
            rejectionReasons: preview.rejectionReasons,
            warnings: preview.warnings,
            plan: preview.plan,
            analysis: preview.analysis
        )
        try encoder.encode(variant).write(
            to: staging.appendingPathComponent("preview.json"),
            options: .atomic
        )

        try fileManager.moveItem(at: staging, to: destination)
        published = true
        return WorkingPlanPreviewResult(directory: destination, variant: variant)
    }

    public func export(
        inputURL: URL,
        prompt: String,
        sourceType: SourceType,
        outputDirectory: URL,
        scopeKind: ScopeKind = .importedFile,
        sourceSnapshotID: UUID? = nil
    ) throws -> PreviewExportResult {
        try export(
            inputURL: inputURL,
            prompt: prompt,
            sourceType: sourceType,
            outputDirectory: outputDirectory,
            scopeKind: scopeKind,
            sourceSnapshotID: sourceSnapshotID,
            productionIntentResult: nil,
            providerMetadata: nil
        )
    }

    /// Renders exactly three candidates owned by a validated TrackSmith
    /// production result. The provider never supplies these nodes or raw
    /// parameters; they were constructed and validated by AgentCore.
    public func exportProductionIntelligence(
        inputURL: URL,
        prompt: String,
        sourceType: SourceType,
        outputDirectory: URL,
        scopeKind: ScopeKind = .importedFile,
        sourceSnapshotID: UUID,
        result: ProductionIntentResult,
        providerMetadata: ProviderExecutionMetadata
    ) throws -> PreviewExportResult {
        try export(
            inputURL: inputURL,
            prompt: prompt,
            sourceType: sourceType,
            outputDirectory: outputDirectory,
            scopeKind: scopeKind,
            sourceSnapshotID: sourceSnapshotID,
            productionIntentResult: result,
            providerMetadata: providerMetadata
        )
    }

    private func export(
        inputURL: URL,
        prompt: String,
        sourceType: SourceType,
        outputDirectory: URL,
        scopeKind: ScopeKind,
        sourceSnapshotID: UUID?,
        productionIntentResult: ProductionIntentResult?,
        providerMetadata: ProviderExecutionMetadata?
    ) throws -> PreviewExportResult {
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { throw PreviewExportError.emptyPrompt }
        let source = try WAVFile.read(url: inputURL)
        guard source.frameCount > 0 else { throw PreviewExportError.noAudioFrames }

        let fileManager = FileManager.default
        let destination = outputDirectory.standardizedFileURL
        guard !fileManager.fileExists(atPath: destination.path) else { throw PreviewExportError.outputAlreadyExists(destination.path) }
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        // A dot-prefixed staging directory receives the macOS hidden flag, which can
        // propagate to its children after rename. Use a visible random sibling and
        // publish it only after every artifact succeeds.
        let staging = parent.appendingPathComponent("\(destination.lastPathComponent)-staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        var moved = false
        defer { if !moved { try? fileManager.removeItem(at: staging) } }

        let analyzer = AudioAnalyzer()
        let originalAnalysis = analyzer.analyze(source)
        let snapshotID = sourceSnapshotID ?? UUID()
        let duration = Double(source.frameCount) / source.sampleRate
        let scope = ProcessingScope(
            kind: scopeKind,
            channelFormat: source.channelCount == 1 ? .mono : .stereo,
            sourceType: sourceType,
            timeRangeSeconds: .init(start: 0, end: duration)
        )
        let candidates: [ExportCandidate]
        if let productionIntentResult {
            candidates = try productionCandidates(
                from: productionIntentResult,
                snapshotID: snapshotID,
                scope: scope
            )
        } else {
            candidates = try DeterministicPlanner()
                .variants(prompt: request, sourceSnapshotID: snapshotID, scope: scope, analysis: originalAnalysis)
                .map { ExportCandidate(variant: $0) }
        }
        let renderer = PreviewRenderer()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let originalFileName = "00-original.wav"
        try WAVFile.writeFloat32(source, url: staging.appendingPathComponent(originalFileName))
        var renderedVariants: [PreviewVariantManifest] = []
        var previousAuditionAudio = source
        var acceptedVariantAudio: [AudioBuffer] = []
        let sourceRMSDBFS = originalAnalysis.metrics["rms_dbfs"]?.value
        let pairwiseDifferenceFloorDBFS = sourceRMSDBFS.map { $0 - 40 } ?? -46
        for (index, candidate) in candidates.enumerated() {
            let variant = candidate.variant
            var preview = try renderer.render(plan: variant.plan, source: source)
            let siblingDifference = try renderer.compare(reference: previousAuditionAudio, candidate: preview.audio)
            if let sourceRMSDBFS,
               sourceRMSDBFS.isFinite,
               preview.difference.differenceRMSDBFS < sourceRMSDBFS - 40 {
                preview.status = .rejected
                preview.rejectionReasons.append(
                    "This level-matched option changed the source by less than the production-intelligence audibility floor and cannot count as a meaningful processed alternative."
                )
            }
            let collapsedTowardAcceptedVariant = try acceptedVariantAudio.contains { prior in
                try renderer.compare(reference: prior, candidate: preview.audio).differenceRMSDBFS
                    < pairwiseDifferenceFloorDBFS
            }
            if index > 0, collapsedTowardAcceptedVariant {
                preview.status = .rejected
                preview.rejectionReasons.append(
                    "This option was too similar to another accepted strength under the configured audio-difference threshold after level matching."
                )
            }
            let prefix = String(format: "%02d", index + 1)
            let baseName = "\(prefix)-\(variant.strength.rawValue)"
            let audioFileName = preview.status == .valid ? "\(baseName).wav" : nil
            if let audioFileName { try WAVFile.writeFloat32(preview.audio, url: staging.appendingPathComponent(audioFileName)) }
            let planFileName = "\(baseName)-plan.json"
            try encoder.encode(preview.plan).write(to: staging.appendingPathComponent(planFileName), options: .atomic)
            renderedVariants.append(.init(
                strength: variant.strength,
                previewID: preview.id,
                status: preview.status,
                audioFileName: audioFileName,
                planFileName: planFileName,
                loudnessMatchGainDB: preview.loudnessMatchGainDB,
                loudnessMatchMethod: preview.loudnessMatchMethod,
                difference: preview.difference,
                pairwiseDifferenceFromPrevious: siblingDifference,
                rejectionReasons: preview.rejectionReasons,
                warnings: preview.warnings,
                plan: preview.plan,
                analysis: preview.analysis,
                candidateIdentifier: candidate.candidateIdentifier,
                hypothesisIdentifier: candidate.hypothesisIdentifier,
                candidateSummary: candidate.summary
            ))
            if preview.status == .valid {
                previousAuditionAudio = preview.audio
                acceptedVariantAudio.append(preview.audio)
            }
        }

        let manifest = PreviewSessionManifest(
            schemaVersion: "1.0",
            createdAt: Date(),
            inputFileName: inputURL.lastPathComponent,
            sourceFingerprint: fingerprint(source),
            prompt: request,
            sourceType: sourceType,
            sampleRate: source.sampleRate,
            channelCount: source.channelCount,
            frameCount: source.frameCount,
            durationSeconds: duration,
            sourceSnapshotID: snapshotID,
            originalAudioFileName: originalFileName,
            originalAnalysis: originalAnalysis,
            variants: renderedVariants,
            productionIntentResult: productionIntentResult,
            providerMetadata: providerMetadata
        )
        try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        try auditionGuide(manifest).data(using: .utf8)!.write(to: staging.appendingPathComponent("AUDITION.txt"), options: .atomic)
        try fileManager.moveItem(at: staging, to: destination)
        moved = true
        return PreviewExportResult(directory: destination, manifest: manifest)
    }

    private struct ExportCandidate {
        var variant: PlanVariant
        var candidateIdentifier: String?
        var hypothesisIdentifier: String?
        var summary: String?

        init(
            variant: PlanVariant,
            candidateIdentifier: String? = nil,
            hypothesisIdentifier: String? = nil,
            summary: String? = nil
        ) {
            self.variant = variant
            self.candidateIdentifier = candidateIdentifier
            self.hypothesisIdentifier = hypothesisIdentifier
            self.summary = summary
        }
    }

    private func productionCandidates(
        from result: ProductionIntentResult,
        snapshotID: UUID,
        scope: ProcessingScope
    ) throws -> [ExportCandidate] {
        guard result.interpretation.sourceType == scope.sourceType else {
            throw PreviewExportError.invalidProductionCandidates("source scope mismatch")
        }
        guard !result.hypotheses.isEmpty else {
            throw PreviewExportError.invalidProductionCandidates("no actionable hypothesis")
        }

        func processingSignature(_ candidate: CandidateProductionPlan) -> String {
            candidate.plan.nodes
                .filter { ![.outputTrim, .loudnessMatch, .limiter, .meter].contains($0.type) }
                .map { node in
                    let parameters = node.parameters
                        .sorted { $0.key.rawValue < $1.key.rawValue }
                        .map { "\($0.key.rawValue)=\(String(format: "%.8g", $0.value))" }
                        .joined(separator: ",")
                    return "\(node.type.rawValue){\(parameters)}"
                }
                .joined(separator: "|")
        }

        var seenSignatures = Set<String>()
        var balanced: [(Int, CandidateProductionPlan)] = []
        for (index, hypothesis) in result.hypotheses.enumerated() {
            guard let candidate = hypothesis.candidatePlans.first(where: { $0.strength == .balanced }) else { continue }
            if seenSignatures.insert(processingSignature(candidate)).inserted {
                balanced.append((index, candidate))
            }
        }

        var selected: [(Int, CandidateProductionPlan)]
        if balanced.count == 1 {
            let index = balanced[0].0
            // The balanced candidates collapsed to one realized graph. Use
            // that hypothesis's complete strength family rather than treating
            // differently worded provider prose as DSP diversity.
            selected = result.hypotheses[index].candidatePlans.map { (index, $0) }
        } else {
            selected = Array(balanced.prefix(3))
            if selected.count < 3 {
                // When two genuinely different balanced approaches exist,
                // prefer an audible stronger member before a conservative
                // fallback. The renderer still owns final audibility, peak,
                // nonfinite, and sibling-collapse rejection.
                for strength in [PreviewStrength.strong, .conservative] {
                    for (index, hypothesis) in result.hypotheses.enumerated() where selected.count < 3 {
                        guard let candidate = hypothesis.candidatePlans.first(where: { $0.strength == strength }) else { continue }
                        if seenSignatures.insert(processingSignature(candidate)).inserted {
                            selected.append((index, candidate))
                        }
                    }
                }
            }
        }
        guard selected.count == 3 else {
            throw PreviewExportError.invalidProductionCandidates("exactly three differentiated candidates are required")
        }
        return try selected.map { hypothesisIndex, candidate in
            guard candidate.plan.sourceSnapshotID == snapshotID,
                  candidate.plan.scope == scope else {
                throw PreviewExportError.invalidProductionCandidates("candidate authority or scope mismatch")
            }
            try PlanValidator().validateForRealtimeActivation(
                candidate.plan,
                currentSnapshotID: snapshotID
            )
            return ExportCandidate(
                variant: .init(strength: candidate.strength, plan: candidate.plan),
                candidateIdentifier: candidate.identifier,
                hypothesisIdentifier: "tracksmith-hypothesis-\(hypothesisIndex + 1)",
                summary: candidate.summary
            )
        }
    }

    private func fingerprint(_ buffer: AudioBuffer) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        func mix(_ byte: UInt8) { value ^= UInt64(byte); value &*= 1_099_511_628_211 }
        for byte in withUnsafeBytes(of: buffer.sampleRate.bitPattern.littleEndian, Array.init) { mix(byte) }
        mix(UInt8(buffer.channelCount))
        for channel in buffer.channels { for sample in channel {
            let bits = sample.bitPattern.littleEndian
            for byte in withUnsafeBytes(of: bits, Array.init) { mix(byte) }
        }}
        return String(format: "%016llx", value)
    }

    private func auditionGuide(_ manifest: PreviewSessionManifest) -> String {
        var lines = [
            "Logic Audio Assistant preview session",
            "",
            "Prompt: \(manifest.prompt)",
            "Source: \(manifest.sourceType.rawValue), \(manifest.channelCount) channel(s), \(Int(manifest.sampleRate)) Hz",
            "",
            "Audition 00-original.wav first, then compare at the same monitoring volume:",
        ]
        for variant in manifest.variants {
            if let file = variant.audioFileName {
                lines.append("- \(file): \(variant.strength.rawValue), valid, \(variant.loudnessMatchMethod.rawValue) match \(String(format: "%.2f", variant.loudnessMatchGainDB)) dB, difference \(String(format: "%.1f", variant.difference.differenceRMSDBFS)) dBFS")
                for warning in variant.warnings { lines.append("  Warning: \(warning)") }
            } else {
                lines.append("- \(variant.strength.rawValue): rejected — \(variant.rejectionReasons.joined(separator: "; "))")
            }
        }
        lines += ["", "Open manifest.json for measurements and every processing parameter.", "No source file was modified or overwritten."]
        return lines.joined(separator: "\n") + "\n"
    }
}
