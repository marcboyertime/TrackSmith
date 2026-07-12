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

    public var description: String {
        switch self {
        case let .outputAlreadyExists(path): "Output directory already exists: \(path)"
        case .emptyPrompt: "The production request cannot be empty."
        case .noAudioFrames: "The input WAV contains no audio frames."
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
    public var rejectionReasons: [String]
    public var warnings: [String]
    public var plan: ProcessingPlan
    public var analysis: AnalysisReport
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

    public var validVariantCount: Int { variants.count { $0.status == .valid } }
}

public struct PreviewExportResult: Sendable {
    public var directory: URL
    public var manifest: PreviewSessionManifest
}

public struct PreviewSessionExporter: Sendable {
    public init() {}

    public func export(inputURL: URL, prompt: String, sourceType: SourceType, outputDirectory: URL) throws -> PreviewExportResult {
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
        let snapshotID = UUID()
        let duration = Double(source.frameCount) / source.sampleRate
        let scope = ProcessingScope(
            kind: .importedFile,
            channelFormat: source.channelCount == 1 ? .mono : .stereo,
            sourceType: sourceType,
            timeRangeSeconds: .init(start: 0, end: duration)
        )
        let plans = try DeterministicPlanner().variants(prompt: request, sourceSnapshotID: snapshotID, scope: scope, analysis: originalAnalysis)
        let renderer = PreviewRenderer()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let originalFileName = "00-original.wav"
        try WAVFile.writeFloat32(source, url: staging.appendingPathComponent(originalFileName))
        var renderedVariants: [PreviewVariantManifest] = []
        for (index, variant) in plans.enumerated() {
            let preview = try renderer.render(plan: variant.plan, source: source)
            let prefix = String(format: "%02d", index + 1)
            let baseName = "\(prefix)-\(variant.strength.rawValue)"
            let audioFileName = preview.status == .valid ? "\(baseName).wav" : nil
            if let audioFileName { try WAVFile.writeFloat32(preview.audio, url: staging.appendingPathComponent(audioFileName)) }
            let planFileName = "\(baseName)-plan.json"
            try encoder.encode(variant.plan).write(to: staging.appendingPathComponent(planFileName), options: .atomic)
            renderedVariants.append(.init(
                strength: variant.strength,
                previewID: preview.id,
                status: preview.status,
                audioFileName: audioFileName,
                planFileName: planFileName,
                loudnessMatchGainDB: preview.loudnessMatchGainDB,
                loudnessMatchMethod: preview.loudnessMatchMethod,
                difference: preview.difference,
                rejectionReasons: preview.rejectionReasons,
                warnings: preview.warnings,
                plan: preview.plan,
                analysis: preview.analysis
            ))
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
            variants: renderedVariants
        )
        try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        try auditionGuide(manifest).data(using: .utf8)!.write(to: staging.appendingPathComponent("AUDITION.txt"), options: .atomic)
        try fileManager.moveItem(at: staging, to: destination)
        moved = true
        return PreviewExportResult(directory: destination, manifest: manifest)
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
