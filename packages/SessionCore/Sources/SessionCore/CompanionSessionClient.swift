import AgentCore
import AudioAnalysis
import CryptoKit
import Darwin
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer
import PreviewWorkflow
import SharedIPC
import VocalProduction

public enum CompanionSessionError: Error, Equatable, CustomStringConvertible, Sendable {
    case noCaptureReply(UUID)
    case replyWasFailure(String)
    case unexpectedReply
    case requestTimedOut(String)
    case capturedInstanceUnavailable
    case artifactSampleRateMismatch(artifactID: UUID, expected: Double, actual: Double)
    case artifactChannelCountMismatch(artifactID: UUID, expected: Int, actual: Int)
    case artifactFrameCountMismatch(artifactID: UUID, expected: Int, actual: Int)
    case captureInstanceMismatch(expected: UUID, actual: UUID?)
    case captureRuntimeMismatch(expected: UUID, actual: UUID?)
    case runtimeAudioFormatUnavailable
    case captureRuntimeSampleRateMismatch(captured: Double, current: Double)
    case captureRuntimeChannelCountMismatch(captured: Int, current: Int)
    case planChannelFormatMismatch(expected: ChannelFormat, actual: ChannelFormat)
    case planPreflightChanged
    case planPreflightRejected([String])
    case commandSequenceExhausted
    case unsupportedSourceAnalysis(SourceType)
    case vocalAssetAlreadyExists(String)
    case vocalAssetWriteVerificationFailed(expected: String, actual: String)
    case vocalSourceAuthorityMismatch(String)

    public var description: String {
        switch self {
        case let .noCaptureReply(id): "No capture reply exists for request \(id)."
        case let .replyWasFailure(message): message
        case .unexpectedReply: "The plug-in returned an unexpected message."
        case let .requestTimedOut(operation):
            "The \(operation) request timed out. The Audio Unit state is unconfirmed; inspect its heartbeat before retrying. No automatic retry was performed."
        case .capturedInstanceUnavailable:
            "The captured Audio Unit instance is no longer available. Capture again before rendering or committing."
        case let .artifactSampleRateMismatch(id, expected, actual):
            "Captured WAV \(id) has sample rate \(actual) Hz, but its immutable descriptor declares \(expected) Hz."
        case let .artifactChannelCountMismatch(id, expected, actual):
            "Captured WAV \(id) has \(actual) channel(s), but its immutable descriptor declares \(expected)."
        case let .artifactFrameCountMismatch(id, expected, actual):
            "Captured WAV \(id) has \(actual) frame(s), but its immutable descriptor declares \(expected)."
        case let .captureInstanceMismatch(expected, actual):
            "The capture belongs to Audio Unit instance \(actual?.uuidString ?? "none"), not \(expected)."
        case let .captureRuntimeMismatch(expected, actual):
            "The capture belongs to runtime \(actual?.uuidString ?? "none"), not \(expected). Capture again before committing."
        case .runtimeAudioFormatUnavailable:
            "The Audio Unit is not currently reporting an allocated audio format. Play or reactivate the insert, then capture again."
        case let .captureRuntimeSampleRateMismatch(captured, current):
            "The Audio Unit sample rate changed after capture (captured \(captured) Hz; current \(current) Hz). Capture again before committing."
        case let .captureRuntimeChannelCountMismatch(captured, current):
            "The Audio Unit channel layout changed after capture (captured \(captured) ch; current \(current) ch). Capture again before committing."
        case let .planChannelFormatMismatch(expected, actual):
            "The plan targets \(actual.rawValue), but the immutable capture is \(expected.rawValue)."
        case .planPreflightChanged:
            "A fresh safety render did not produce the exact materialized plan requested for commit."
        case let .planPreflightRejected(reasons):
            "The fresh safety render rejected the commit: \(reasons.joined(separator: " "))"
        case .commandSequenceExhausted:
            "This Audio Unit runtime has exhausted its command sequence space. Reopen the insert before sending another command."
        case let .unsupportedSourceAnalysis(sourceType):
            "Source-aware analysis v1 does not support \(sourceType.rawValue). Choose vocal, drums, bass, guitar, synth/keys, or full mix."
        case let .vocalAssetAlreadyExists(path):
            "The immutable Vocal asset destination already exists: \(path)"
        case let .vocalAssetWriteVerificationFailed(expected, actual):
            "The published Vocal asset did not reproduce its in-memory render hash (expected \(expected), received \(actual))."
        case let .vocalSourceAuthorityMismatch(reason):
            "The caller-provided Vocal source authority does not match this immutable capture: \(reason)"
        }
    }
}

public enum AppliedCommandExpectation: Equatable, Sendable {
    case plan(ProcessingPlan)
    case globalBypass(Bool)
}

public enum CommandResolution: Equatable, Sendable {
    case acknowledged(ExchangeMessage)
    case reconciled(PluginInstanceRecord)
    case rejected(ExchangeMessage)
}

/// One TrackSmith-owned, locally rendered Vocal asset. The source capture is
/// never overwritten; audio and provenance become visible together only after
/// both have been written and the WAV has reproduced the renderer's hash.
public struct VocalRenderedAssetExportResult: Sendable {
    public var directory: URL
    public var sourceAudioURL: URL
    public var audioURL: URL
    public var manifestURL: URL
    public var asset: VocalRenderedAsset

    public init(
        directory: URL,
        sourceAudioURL: URL,
        audioURL: URL,
        manifestURL: URL,
        asset: VocalRenderedAsset
    ) {
        self.directory = directory
        self.sourceAudioURL = sourceAudioURL
        self.audioURL = audioURL
        self.manifestURL = manifestURL
        self.asset = asset
    }
}

/// Non-UI orchestration for one durable companion/AU session. Natural-language and
/// preview work stays in the companion; the AU receives only validated plans.
public actor CompanionSessionClient {
    private let exchange: FileExchange
    private var lastMailboxMaintenance = Date.distantPast
    private var nextCommandSequenceByRuntime: [UUID: UInt64] = [:]

    public init(exchange: FileExchange) { self.exchange = exchange }

    public init(appGroup fileManager: FileManager = .default) throws {
        exchange = try FileExchange(appGroup: fileManager)
    }

    public func activeInstances(now: Date = Date()) throws -> InstanceScan {
        try performMailboxMaintenanceIfDue(now: now)
        return try exchange.scanInstances(now: now)
    }

    @discardableResult
    public func performMailboxMaintenanceIfDue(
        now: Date = Date(),
        minimumInterval: TimeInterval = 60
    ) throws -> MailboxMaintenanceResult? {
        guard now.timeIntervalSince(lastMailboxMaintenance) >= minimumInterval else {
            return nil
        }
        let result = try exchange.performMailboxMaintenance(now: now)
        lastMailboxMaintenance = now
        return result
    }

    public func deleteAllCachedAudio() throws -> CachePurgeResult {
        try exchange.deleteAllCachedAudio()
    }

    @discardableResult
    public func requestRecentCapture(instance: PluginInstanceRecord, durationSeconds: Double = 15) throws -> UUID {
        try performMailboxMaintenanceIfDue()
        let message = ExchangeMessage(
            kind: .captureRecentRequest,
            instanceID: instance.id,
            targetRuntimeEpoch: instance.runtimeEpoch,
            sender: .companion,
            expiresAt: Date(timeIntervalSinceNow: 30),
            commandSequence: try nextCommandSequence(for: instance),
            captureRequest: CaptureRequest(maxDurationSeconds: durationSeconds)
        )
        try exchange.send(message)
        return message.id
    }

    public func pluginMessages(instanceID: UUID) throws -> ExchangeScan {
        try exchange.scan(instanceID: instanceID, sender: .plugin)
    }

    public func captureReply(requestID: UUID, instanceID: UUID) throws -> (CaptureArtifact, URL)? {
        let replies = try verifiedTerminalReplies(requestID: requestID, instanceID: instanceID)
        if let failure = replies.first(where: { $0.kind == .failure }) {
            throw CompanionSessionError.replyWasFailure(failure.text ?? "The plug-in capture failed.")
        }
        guard let reply = replies.first(where: { $0.kind == .captureReady }) else { return nil }
        guard let artifact = reply.captureArtifact else { throw CompanionSessionError.unexpectedReply }
        return (artifact, try exchange.resolveArtifact(artifact))
    }

    public func renderPreviews(
        artifact: CaptureArtifact,
        prompt: String,
        sourceType: SourceType
    ) throws -> PreviewExportResult {
        let inputURL = try exchange.resolveArtifact(artifact)
        _ = try loadCapturedAudio(artifact)
        let outputURL = try exchange.previewDirectory(captureID: artifact.id)
        let result = try PreviewSessionExporter().export(
            inputURL: inputURL,
            prompt: prompt,
            sourceType: sourceType,
            outputDirectory: outputURL,
            scopeKind: .pluginInput,
            sourceSnapshotID: artifact.id
        )
        // Do not return a preview if its immutable capture changed while the
        // renderer was working. `resolveArtifact` verifies the artifact hash.
        _ = try exchange.resolveArtifact(artifact)
        return result
    }

    public func analyzeCapture(
        artifact: CaptureArtifact,
        sourceType: SourceType
    ) throws -> SourceAwareAnalysisReport {
        let buffer = try loadCapturedAudio(artifact)
        let sourceClass: SourceAnalysisClass = switch sourceType {
        case .vocal, .vocalBus: .vocal
        case .drums, .drumBus: .drums
        case .bass: .bass
        case .guitar: .guitar
        case .keyboard, .synth: .synthKeys
        case .fullMix: .fullStereoMix
        case .reference, .unknown:
            throw CompanionSessionError.unsupportedSourceAnalysis(sourceType)
        }
        return SourceAwareAudioAnalyzer().analyze(buffer, as: sourceClass)
    }

    public func renderProductionIntelligencePreviews(
        artifact: CaptureArtifact,
        prompt: String,
        sourceType: SourceType,
        result: ProductionIntentResult,
        providerMetadata: ProviderExecutionMetadata
    ) throws -> PreviewExportResult {
        let inputURL = try exchange.resolveArtifact(artifact)
        _ = try loadCapturedAudio(artifact)
        let outputURL = try exchange.previewDirectory(captureID: artifact.id)
        let preview = try PreviewSessionExporter().exportProductionIntelligence(
            inputURL: inputURL,
            prompt: prompt,
            sourceType: sourceType,
            outputDirectory: outputURL,
            scopeKind: .pluginInput,
            sourceSnapshotID: artifact.id,
            result: result,
            providerMetadata: providerMetadata
        )
        _ = try exchange.resolveArtifact(artifact)
        return preview
    }

    /// Renders the three locally validated TrackSmith Vocal interpretations
    /// against the exact immutable AU capture. The candidates already contain
    /// bounded ProcessingPlans; this boundary revalidates their capture/scope
    /// authority and never accepts provider-authored nodes or parameters.
    public func renderVocalPreviews(
        artifact: CaptureArtifact,
        prompt: String,
        sourceType: SourceType,
        candidates: [VocalCreativeCandidate]
    ) throws -> PreviewExportResult {
        let inputURL = try exchange.resolveArtifact(artifact)
        _ = try loadCapturedAudio(artifact)
        let outputURL = try exchange.previewDirectory(captureID: artifact.id)
        let preview = try PreviewSessionExporter().exportVocalCandidates(
            inputURL: inputURL,
            prompt: prompt,
            sourceType: sourceType,
            outputDirectory: outputURL,
            scopeKind: .pluginInput,
            sourceSnapshotID: artifact.id,
            candidates: candidates
        )
        _ = try exchange.resolveArtifact(artifact)
        return preview
    }

    /// Renders a Vocal candidate as an explicitly new local asset. This is the
    /// only execution path for section- or time-scoped candidates because the
    /// current AU owns a full-source graph and does not claim host automation
    /// or region authority. The renderer preserves the supplied source buffer,
    /// validates its typed hash/scope/locks, and blends only inside the exact
    /// authorized frame range.
    public func renderVocalAsset(
        artifact: CaptureArtifact,
        sourceAuthority: VocalSourceAuthority,
        candidate: VocalCreativeCandidate,
        renderID: UUID = UUID(),
        parentPreviewID: UUID? = nil,
        parentAssetID: UUID? = nil,
        assetAncestry: [UUID] = [],
        randomSeed: UInt64? = nil,
        crossfadeSeconds: Double = 0.01,
        createdAt: Date = Date()
    ) throws -> VocalRenderedAssetExportResult {
        let source = try resolveVocalSource(artifact, authority: sourceAuthority)
        let hasher = VocalAudioHasher()
        let request = VocalScopedRenderRequest(
            renderID: renderID,
            candidate: candidate,
            sourceAuthority: sourceAuthority,
            randomSeed: randomSeed,
            parentPreviewID: parentPreviewID,
            parentAssetID: parentAssetID,
            assetAncestry: assetAncestry,
            createdAt: createdAt,
            crossfadeSeconds: crossfadeSeconds,
            thirdPartyMaterialStatus: .noneUsed
        )
        let rendered = try VocalScopedAssetRenderer().render(source: source, request: request)

        let destination = try exchange.previewDirectory(captureID: artifact.id, requestID: renderID)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CompanionSessionError.vocalAssetAlreadyExists(destination.path)
        }
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        let staging = parent.appendingPathComponent(
            "\(renderID.uuidString.lowercased())-staging-\(UUID().uuidString.lowercased())",
            isDirectory: true
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: staging.path)
        var published = false
        defer { if !published { try? fileManager.removeItem(at: staging) } }

        let sourceAudioName = "00-original.wav"
        let audioName = "rendered-vocal.wav"
        let manifestName = "manifest.json"
        let stagedSourceAudio = staging.appendingPathComponent(sourceAudioName)
        let stagedAudio = staging.appendingPathComponent(audioName)
        let stagedManifest = staging.appendingPathComponent(manifestName)
        try WAVFile.writeFloat32(source, url: stagedSourceAudio)
        try WAVFile.writeFloat32(rendered.audio, url: stagedAudio)
        let sourceRoundTripHash = try hasher.sha256(WAVFile.read(url: stagedSourceAudio))
        guard sourceRoundTripHash == sourceAuthority.contentHashSHA256 else {
            throw CompanionSessionError.vocalAssetWriteVerificationFailed(
                expected: sourceAuthority.contentHashSHA256,
                actual: sourceRoundTripHash
            )
        }
        let roundTripped = try WAVFile.read(url: stagedAudio)
        let roundTripHash = try hasher.sha256(roundTripped)
        guard roundTripHash == rendered.manifest.renderHashSHA256 else {
            throw CompanionSessionError.vocalAssetWriteVerificationFailed(
                expected: rendered.manifest.renderHashSHA256,
                actual: roundTripHash
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Vocal provenance requires exact save/reload identity. Foundation's
        // default ISO-8601 strategy discards subsecond precision, so store the
        // exact Date scalar for this new versioned manifest format.
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(rendered.manifest).write(to: stagedManifest, options: .atomic)

        // Re-resolve and revalidate the immutable capture after all off-render
        // work. A caller cannot receive a published asset if its exact
        // caller-validated authority changed mid-run.
        _ = try resolveVocalSource(artifact, authority: sourceAuthority)
        try fileManager.moveItem(at: staging, to: destination)
        published = true
        return VocalRenderedAssetExportResult(
            directory: destination,
            sourceAudioURL: destination.appendingPathComponent(sourceAudioName),
            audioURL: destination.appendingPathComponent(audioName),
            manifestURL: destination.appendingPathComponent(manifestName),
            asset: rendered
        )
    }

    /// Compiles a bounded conversational edit against the exact current
    /// working plan, then renders it from the same immutable capture used by
    /// the original preview set. `PlanRevisionEngine` preserves unmentioned
    /// nodes and the validator rejects any mutation of locked nodes.
    public func renderRevisionPreview(
        artifact: CaptureArtifact,
        basePlan: ProcessingPlan,
        request: String
    ) throws -> WorkingPlanPreviewResult {
        let revised = try PreviewSessionExporter().revise(plan: basePlan, request: request)
        return try renderWorkingPlanPreview(artifact: artifact, plan: revised)
    }

    /// Renders a user-authored graph edit (for example a per-node bypass) after
    /// verifying both the capture descriptor and its source-snapshot binding.
    public func renderWorkingPlanPreview(
        artifact: CaptureArtifact,
        plan: ProcessingPlan
    ) throws -> WorkingPlanPreviewResult {
        try PlanValidator().validateForRealtimeActivation(plan, currentSnapshotID: artifact.id)
        let inputURL = try exchange.resolveArtifact(artifact)
        _ = try loadCapturedAudio(artifact)
        let outputURL = try exchange.previewDirectory(captureID: artifact.id)
        let preview = try PreviewSessionExporter().renderWorkingPlan(
            inputURL: inputURL,
            plan: plan,
            outputDirectory: outputURL
        )
        _ = try exchange.resolveArtifact(artifact)
        return preview
    }

    /// Resolves, hashes, decodes, and metadata-checks a capture before UI or
    /// preview code is allowed to use its samples.
    public func loadCapturedAudio(_ artifact: CaptureArtifact) throws -> AudioBuffer {
        let inputURL = try exchange.resolveArtifact(artifact)
        let capturedAudio = try WAVFile.read(url: inputURL)
        try validate(capturedAudio: capturedAudio, against: artifact)
        return capturedAudio
    }

    /// Returns one bounded, hash-bound WAV byte snapshot for an explicitly
    /// consented Tutor listening request. No model-facing API receives this
    /// method, the filesystem URL, or the broader session client.
    public func loadValidatedCaptureWAVData(
        _ artifact: CaptureArtifact,
        maximumBytes: Int = 24 * 1_024 * 1_024
    ) throws -> Data {
        guard maximumBytes > 0, maximumBytes <= 24 * 1_024 * 1_024 else {
            throw ExchangeError.artifactTooLarge
        }
        let inputURL = try exchange.resolveArtifact(artifact)
        let descriptor = Darwin.open(inputURL.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw ExchangeError.invalidArtifactPath }
        defer { Darwin.close(descriptor) }
        var status = stat()
        guard Darwin.fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG,
              status.st_size >= 0 else { throw ExchangeError.invalidArtifactPath }
        guard status.st_size <= maximumBytes else { throw ExchangeError.artifactTooLarge }
        // Deliberately copy from one no-follow descriptor instead of memory-mapping:
        // the digest, WAV decoder, and provider encoder must observe the same stable
        // in-memory snapshot even if another same-App-Group process misbehaves.
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        var data = Data()
        while data.count <= maximumBytes {
            let remaining = maximumBytes + 1 - data.count
            let chunk = try handle.read(upToCount: min(64 * 1_024, remaining)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= maximumBytes,
              (try handle.read(upToCount: 1) ?? Data()).isEmpty else {
            throw ExchangeError.artifactTooLarge
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == artifact.sha256 else { throw ExchangeError.artifactHashMismatch }
        let capturedAudio = try WAVFile.read(data: data)
        try validate(capturedAudio: capturedAudio, against: artifact)
        return data
    }

    /// A Vocal asset must retain the exact source authority that the caller
    /// validated against its completed capture/test-take context. This client
    /// verifies the immutable bytes and artifact binding, but deliberately
    /// never manufactures a replacement generic capture identity.
    private func resolveVocalSource(
        _ artifact: CaptureArtifact,
        authority: VocalSourceAuthority
    ) throws -> AudioBuffer {
        let source = try loadCapturedAudio(artifact)
        let resolved = try VocalAudioHasher().authority(
            for: source,
            sourceSnapshotID: artifact.id,
            immutableSourceID: authority.immutableSourceID,
            capturedAt: artifact.createdAt
        )
        guard resolved == authority else {
            throw CompanionSessionError.vocalSourceAuthorityMismatch(
                "source snapshot, immutable ID, hash, format, frame count, or capture timestamp changed"
            )
        }
        return source
    }

    private func validate(capturedAudio: AudioBuffer, against artifact: CaptureArtifact) throws {
        guard capturedAudio.sampleRate == artifact.sampleRate else {
            throw CompanionSessionError.artifactSampleRateMismatch(
                artifactID: artifact.id,
                expected: artifact.sampleRate,
                actual: capturedAudio.sampleRate
            )
        }
        guard capturedAudio.channelCount == artifact.channelCount else {
            throw CompanionSessionError.artifactChannelCountMismatch(
                artifactID: artifact.id,
                expected: artifact.channelCount,
                actual: capturedAudio.channelCount
            )
        }
        guard capturedAudio.frameCount == artifact.frameCount else {
            throw CompanionSessionError.artifactFrameCountMismatch(
                artifactID: artifact.id,
                expected: artifact.frameCount,
                actual: capturedAudio.frameCount
            )
        }
    }

    @discardableResult
    public func commit(
        plan: ProcessingPlan,
        artifact: CaptureArtifact,
        originatingInstance instance: PluginInstanceRecord,
        expectedCurrentPlan: ProcessingPlan?,
        allowLockedNodeRemoval: Bool = false
    ) throws -> UUID {
        guard artifact.originatingInstanceID == instance.id else {
            throw CompanionSessionError.captureInstanceMismatch(
                expected: instance.id,
                actual: artifact.originatingInstanceID
            )
        }
        guard artifact.originatingRuntimeEpoch == instance.runtimeEpoch else {
            throw CompanionSessionError.captureRuntimeMismatch(
                expected: instance.runtimeEpoch,
                actual: artifact.originatingRuntimeEpoch
            )
        }
        guard let currentSampleRate = instance.sampleRate,
              let currentChannelCount = instance.channelCount else {
            throw CompanionSessionError.runtimeAudioFormatUnavailable
        }
        guard artifact.sampleRate == currentSampleRate else {
            throw CompanionSessionError.captureRuntimeSampleRateMismatch(
                captured: artifact.sampleRate,
                current: currentSampleRate
            )
        }
        guard artifact.channelCount == currentChannelCount else {
            throw CompanionSessionError.captureRuntimeChannelCountMismatch(
                captured: artifact.channelCount,
                current: currentChannelCount
            )
        }
        let captureChannelFormat: ChannelFormat = artifact.channelCount == 1 ? .mono : .stereo
        guard plan.scope.channelFormat == captureChannelFormat else {
            throw CompanionSessionError.planChannelFormatMismatch(
                expected: captureChannelFormat,
                actual: plan.scope.channelFormat
            )
        }
        try PlanValidator().validateForRealtimeActivation(
            plan,
            currentSnapshotID: artifact.id,
            basePlan: allowLockedNodeRemoval ? nil : expectedCurrentPlan
        )
        let capturedAudio = try loadCapturedAudio(artifact)
        try validateExactSafetyRender(plan: plan, source: capturedAudio)
        // Re-hash after the render as the last pre-send check. A commit message
        // is never published if the immutable source changed during preflight.
        _ = try exchange.resolveArtifact(artifact)
        try performMailboxMaintenanceIfDue()
        let message = ExchangeMessage(
            kind: .planCommitRequest,
            instanceID: instance.id,
            targetRuntimeEpoch: instance.runtimeEpoch,
            sender: .companion,
            expiresAt: Date(timeIntervalSinceNow: 30),
            commandSequence: try nextCommandSequence(for: instance),
            captureArtifact: artifact,
            plan: plan,
            expectedCurrentPlanState: ExpectedCurrentPlanState(plan: expectedCurrentPlan),
            allowLockedNodeRemoval: allowLockedNodeRemoval
        )
        try exchange.send(message)
        return message.id
    }

    /// Changes only the Audio Unit's global audition bypass. The committed
    /// processing graph remains loaded and serialized for an exact restore.
    @discardableResult
    public func setGlobalBypass(
        enabled: Bool,
        instance: PluginInstanceRecord
    ) throws -> UUID {
        try performMailboxMaintenanceIfDue()
        let message = ExchangeMessage(
            kind: .globalBypassRequest,
            instanceID: instance.id,
            targetRuntimeEpoch: instance.runtimeEpoch,
            sender: .companion,
            expiresAt: Date(timeIntervalSinceNow: 30),
            commandSequence: try nextCommandSequence(for: instance),
            globalBypassRequest: GlobalBypassRequest(enabled: enabled)
        )
        try exchange.send(message)
        return message.id
    }

    public func terminalReply(requestID: UUID, instanceID: UUID) throws -> ExchangeMessage? {
        let replies = try verifiedTerminalReplies(requestID: requestID, instanceID: instanceID)
        return replies.first(where: { $0.kind == .failure })
            ?? replies.first(where: { $0.kind == .captureReady })
            ?? replies.first(where: { $0.kind == .acknowledgement })
    }

    /// Resolves an operation from durable AU state before considering mailbox
    /// replies. This makes an acknowledgement write failure distinguishable
    /// from an apply failure and prevents unsafe blind retries.
    public func commandResolution(
        requestID: UUID,
        instanceID: UUID,
        runtimeEpoch: UUID,
        expectation: AppliedCommandExpectation
    ) throws -> CommandResolution? {
        if let record = try activeInstances().instances.first(where: {
            $0.id == instanceID && $0.runtimeEpoch == runtimeEpoch
        }), record.lastAppliedCommandID == requestID {
            switch expectation {
            case let .plan(plan):
                if record.lastAppliedPlanRequestID == plan.requestID,
                   record.currentPlan == plan {
                    return .reconciled(record)
                }
            case let .globalBypass(enabled):
                if record.lastAppliedPlanRequestID == nil,
                   record.globalBypassEnabled == enabled {
                    return .reconciled(record)
                }
            }
        }

        let replies = try verifiedTerminalReplies(
            requestID: requestID,
            instanceID: instanceID,
            expectedRuntimeEpoch: runtimeEpoch
        )
        if let acknowledgement = replies.first(where: { $0.kind == .acknowledgement }) {
            return .acknowledged(acknowledgement)
        }
        if let failure = replies.first(where: { $0.kind == .failure }) {
            return .rejected(failure)
        }
        return nil
    }

    /// Terminal messages are untrusted mailbox input until they are tied back
    /// to the exact companion command, AU instance, runtime epoch, and legal
    /// response kind. In particular, a reply from a restarted instance must
    /// never resolve a request issued to the prior runtime.
    private func verifiedTerminalReplies(
        requestID: UUID,
        instanceID: UUID,
        expectedRuntimeEpoch: UUID? = nil
    ) throws -> [ExchangeMessage] {
        let command: ExchangeMessage
        do {
            command = try exchange.receive(id: requestID)
        } catch ExchangeError.messageNotFound {
            return []
        }
        guard command.sender == .companion,
              command.instanceID == instanceID,
              let commandRuntimeEpoch = command.targetRuntimeEpoch,
              expectedRuntimeEpoch.map({ $0 == commandRuntimeEpoch }) ?? true else {
            return []
        }

        let allowedKinds: Set<ExchangeMessageKind>
        switch command.kind {
        case .captureRecentRequest:
            allowedKinds = [.captureReady, .failure]
        case .planCommitRequest, .globalBypassRequest:
            allowedKinds = [.acknowledgement, .failure]
        default:
            return []
        }

        return try pluginMessages(instanceID: instanceID).messages.filter { reply in
            reply.sender == .plugin &&
                reply.correlationID == requestID &&
                reply.targetRuntimeEpoch == commandRuntimeEpoch &&
                allowedKinds.contains(reply.kind)
        }
    }

    private func validateExactSafetyRender(
        plan: ProcessingPlan,
        source: AudioBuffer
    ) throws {
        let audible = plan.nodes.contains { $0.enabled && $0.type != .meter }
        let hasMaterializedLoudnessMatch = plan.nodes.contains { $0.type == .loudnessMatch }
        if audible, plan.outputConstraints.loudnessMatchPreview, !hasMaterializedLoudnessMatch {
            throw CompanionSessionError.planPreflightChanged
        }

        var evaluationPlan = plan
        // A dry plan or an explicitly disabled match node must remain exact;
        // prevent the renderer from synthesizing a comparison-only gain node.
        if !audible || evaluationPlan.nodes.contains(where: {
            $0.type == .loudnessMatch && !$0.enabled
        }) {
            evaluationPlan.outputConstraints.loudnessMatchPreview = false
        }

        // Commit preflight is intentionally in memory. It uses the same
        // deterministic renderer as previews but never writes duplicate audio
        // that could survive a companion crash.
        let result = try PreviewRenderer().render(plan: evaluationPlan, source: source)
        var renderedPlan = result.plan
        renderedPlan.outputConstraints = plan.outputConstraints
        guard renderedPlan == plan,
              try canonicalPlanData(renderedPlan) == canonicalPlanData(plan) else {
            throw CompanionSessionError.planPreflightChanged
        }
        guard result.status == .valid else {
            throw CompanionSessionError.planPreflightRejected(result.rejectionReasons)
        }
    }

    private func nextCommandSequence(for instance: PluginInstanceRecord) throws -> UInt64 {
        let persistedNext: UInt64
        if let last = instance.lastProcessedCommandSequence {
            guard last < UInt64.max else { throw CompanionSessionError.commandSequenceExhausted }
            persistedNext = last + 1
        } else {
            persistedNext = 1
        }
        let next = max(nextCommandSequenceByRuntime[instance.runtimeEpoch] ?? 1, persistedNext)
        guard next < UInt64.max else { throw CompanionSessionError.commandSequenceExhausted }
        nextCommandSequenceByRuntime[instance.runtimeEpoch] = next + 1
        return next
    }

    private func canonicalPlanData(_ plan: ProcessingPlan) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(plan)
    }
}
