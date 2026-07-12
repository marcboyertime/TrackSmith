import DSPCore
import Foundation
import PlanSchema

public enum PreviewSessionLoadError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingManifest(String)
    case invalidManifest(String)
    case unsafeFileName(String)
    case missingArtifact(String)
    case planMismatch(String)
    case audioFormatMismatch(file: String, expected: String, actual: String)
    case duplicateStrength(String)

    public var description: String {
        switch self {
        case let .missingManifest(path): "No manifest.json exists at \(path)."
        case let .invalidManifest(reason): "The preview manifest is invalid: \(reason)"
        case let .unsafeFileName(name): "The manifest contains an unsafe artifact name: \(name)"
        case let .missingArtifact(name): "A required preview artifact is missing: \(name)"
        case let .planMismatch(name): "The saved plan does not match the manifest: \(name)"
        case let .audioFormatMismatch(file, expected, actual): "\(file) has \(actual); expected \(expected)."
        case let .duplicateStrength(strength): "The manifest contains duplicate \(strength) variants."
        }
    }
}

public struct LoadedPreviewVariant: Sendable {
    public var manifest: PreviewVariantManifest
    public var audioURL: URL?
    public var planURL: URL
}

public struct LoadedPreviewSession: Sendable {
    public var directory: URL
    public var manifestURL: URL
    public var manifest: PreviewSessionManifest
    public var originalAudioURL: URL
    public var variants: [LoadedPreviewVariant]

    public var auditionableVariants: [LoadedPreviewVariant] {
        variants.filter { $0.manifest.status == .valid && $0.audioURL != nil }
    }
}

public struct PreviewSessionLoader: Sendable {
    public init() {}

    public func load(directory: URL) throws -> LoadedPreviewSession {
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        let manifestURL = root.appendingPathComponent("manifest.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PreviewSessionLoadError.missingManifest(manifestURL.path)
        }

        let manifest: PreviewSessionManifest
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            manifest = try decoder.decode(PreviewSessionManifest.self, from: Data(contentsOf: manifestURL))
        } catch {
            throw PreviewSessionLoadError.invalidManifest(String(describing: error))
        }
        guard manifest.schemaVersion == "1.0" else {
            throw PreviewSessionLoadError.invalidManifest("unsupported schema version \(manifest.schemaVersion)")
        }
        guard manifest.sampleRate > 0, manifest.channelCount == 1 || manifest.channelCount == 2,
              manifest.frameCount > 0, manifest.durationSeconds > 0 else {
            throw PreviewSessionLoadError.invalidManifest("invalid audio metadata")
        }

        let originalURL = try artifactURL(named: manifest.originalAudioFileName, root: root)
        try requireFile(originalURL, name: manifest.originalAudioFileName)
        try validateAudio(originalURL, named: manifest.originalAudioFileName, manifest: manifest)

        var strengths = Set<String>()
        var loadedVariants: [LoadedPreviewVariant] = []
        for variant in manifest.variants {
            guard strengths.insert(variant.strength.rawValue).inserted else {
                throw PreviewSessionLoadError.duplicateStrength(variant.strength.rawValue)
            }
            guard variant.plan.sourceSnapshotID == manifest.sourceSnapshotID else {
                throw PreviewSessionLoadError.planMismatch(variant.planFileName)
            }
            let planURL = try artifactURL(named: variant.planFileName, root: root)
            try requireFile(planURL, name: variant.planFileName)
            let diskPlan: ProcessingPlan
            do {
                diskPlan = try JSONDecoder().decode(ProcessingPlan.self, from: Data(contentsOf: planURL))
            } catch {
                throw PreviewSessionLoadError.invalidManifest("could not decode \(variant.planFileName): \(error)")
            }
            guard diskPlan == variant.plan else { throw PreviewSessionLoadError.planMismatch(variant.planFileName) }

            let audioURL: URL?
            if let name = variant.audioFileName {
                let candidate = try artifactURL(named: name, root: root)
                try requireFile(candidate, name: name)
                try validateAudio(candidate, named: name, manifest: manifest)
                audioURL = candidate
            } else {
                guard variant.status == .rejected else {
                    throw PreviewSessionLoadError.invalidManifest("valid variant \(variant.strength.rawValue) has no audio file")
                }
                audioURL = nil
            }
            loadedVariants.append(.init(manifest: variant, audioURL: audioURL, planURL: planURL))
        }

        return .init(
            directory: root,
            manifestURL: manifestURL,
            manifest: manifest,
            originalAudioURL: originalURL,
            variants: loadedVariants
        )
    }

    private func artifactURL(named name: String, root: URL) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
              URL(fileURLWithPath: name).lastPathComponent == name else {
            throw PreviewSessionLoadError.unsafeFileName(name)
        }
        let url = root.appendingPathComponent(name, isDirectory: false).standardizedFileURL.resolvingSymlinksInPath()
        guard url.deletingLastPathComponent() == root else { throw PreviewSessionLoadError.unsafeFileName(name) }
        return url
    }

    private func requireFile(_ url: URL, name: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw PreviewSessionLoadError.missingArtifact(name)
        }
    }

    private func validateAudio(_ url: URL, named name: String, manifest: PreviewSessionManifest) throws {
        let audio: AudioBuffer
        do { audio = try WAVFile.read(url: url) }
        catch { throw PreviewSessionLoadError.invalidManifest("could not decode \(name): \(error)") }
        let expected = "\(manifest.channelCount) channel(s), \(Int(manifest.sampleRate)) Hz, \(manifest.frameCount) frames"
        let actual = "\(audio.channelCount) channel(s), \(Int(audio.sampleRate)) Hz, \(audio.frameCount) frames"
        guard audio.channelCount == manifest.channelCount,
              abs(audio.sampleRate - manifest.sampleRate) < 0.5,
              audio.frameCount == manifest.frameCount else {
            throw PreviewSessionLoadError.audioFormatMismatch(file: name, expected: expected, actual: actual)
        }
    }
}
