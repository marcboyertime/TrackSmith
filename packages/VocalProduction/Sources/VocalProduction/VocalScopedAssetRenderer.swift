import CryptoKit
import DSPCore
import Foundation
import PlanSchema

public enum VocalThirdPartyMaterialStatus: String, Codable, CaseIterable, Sendable {
    case noneUsed
    case callerDeclaredLicensedMaterial
    case unsupportedOrUnknown
}

public struct VocalEngineIdentity: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var engineIdentifier: String
    public var engineVersion: String
    public var pipelineIdentifier: String
    public var pipelineVersion: String

    public init(
        version: VocalSchemaVersion = .v1,
        engineIdentifier: String,
        engineVersion: String,
        pipelineIdentifier: String,
        pipelineVersion: String
    ) {
        self.version = version
        self.engineIdentifier = engineIdentifier
        self.engineVersion = engineVersion
        self.pipelineIdentifier = pipelineIdentifier
        self.pipelineVersion = pipelineVersion
    }

    public static let trackSmithVocalV1 = VocalEngineIdentity(
        engineIdentifier: "tracksmith.vocal.scoped-renderer",
        engineVersion: "1.0",
        pipelineIdentifier: "tracksmith.dspcore.compiled-graph",
        pipelineVersion: "1.0"
    )
}

public enum VocalBoundaryDisposition: String, Codable, CaseIterable, Sendable {
    case editablePlanOnly
    case editablePlanPreferred
    case localRenderedAssetAllowed
    case localRenderedAssetRequired
}

public struct VocalBoundaryDecision: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var disposition: VocalBoundaryDisposition
    public var reason: String
    public var usesNetwork: Bool
    public var permitsThirdPartyMaterial: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        disposition: VocalBoundaryDisposition,
        reason: String,
        usesNetwork: Bool = false,
        permitsThirdPartyMaterial: Bool = false
    ) {
        self.version = version
        self.disposition = disposition
        self.reason = reason
        self.usesNetwork = usesNetwork
        self.permitsThirdPartyMaterial = permitsThirdPartyMaterial
    }
}

public struct VocalProcessingBoundaryEvaluator: Sendable {
    public init() {}

    public func decision(for intent: VocalCreativeIntent) -> VocalBoundaryDecision {
        switch intent.assetAcceptance {
        case .editableDSPOnly, .rejectRenderedAssets:
            return VocalBoundaryDecision(
                disposition: .editablePlanOnly,
                reason: "The typed intent authorizes editable processing only; no rendered asset may be created."
            )
        case .allowLocalRenderedAsset where intent.scope.kind == .fullSource:
            return VocalBoundaryDecision(
                disposition: .editablePlanPreferred,
                reason: "Whole-source deterministic DSP remains fully editable and need not masquerade as a new asset; explicit local rendering is still allowed."
            )
        case .allowLocalRenderedAsset:
            return VocalBoundaryDecision(
                disposition: .localRenderedAssetAllowed,
                reason: "The typed intent allows a local rendered asset, including a scoped blend with exact outside-source preservation."
            )
        case .requireLocalRenderedAsset:
            return VocalBoundaryDecision(
                disposition: .localRenderedAssetRequired,
                reason: "The typed intent explicitly requires a local rendered asset."
            )
        }
    }
}

public struct VocalScopedRenderRequest: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var renderID: UUID
    public var candidate: VocalCreativeCandidate
    public var sourceAuthority: VocalSourceAuthority
    public var engine: VocalEngineIdentity
    public var randomSeed: UInt64?
    public var parentPreviewID: UUID?
    public var parentAssetID: UUID?
    public var assetAncestry: [UUID]
    public var createdAt: Date
    public var crossfadeSeconds: Double
    public var thirdPartyMaterialStatus: VocalThirdPartyMaterialStatus

    public init(
        version: VocalSchemaVersion = .v1,
        renderID: UUID,
        candidate: VocalCreativeCandidate,
        sourceAuthority: VocalSourceAuthority,
        engine: VocalEngineIdentity = .trackSmithVocalV1,
        randomSeed: UInt64? = nil,
        parentPreviewID: UUID? = nil,
        parentAssetID: UUID? = nil,
        assetAncestry: [UUID] = [],
        createdAt: Date,
        crossfadeSeconds: Double = 0.01,
        thirdPartyMaterialStatus: VocalThirdPartyMaterialStatus = .noneUsed
    ) {
        self.version = version
        self.renderID = renderID
        self.candidate = candidate
        self.sourceAuthority = sourceAuthority
        self.engine = engine
        self.randomSeed = randomSeed
        self.parentPreviewID = parentPreviewID
        self.parentAssetID = parentAssetID
        self.assetAncestry = assetAncestry
        self.createdAt = createdAt
        self.crossfadeSeconds = crossfadeSeconds
        self.thirdPartyMaterialStatus = thirdPartyMaterialStatus
    }
}

public struct VocalRenderedAssetManifest: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var renderID: UUID
    public var renderHashSHA256: String
    public var sourceAuthority: VocalSourceAuthority
    public var originalPrompt: String
    public var typedIntent: VocalCreativeIntent
    public var preservation: VocalPreservationContract
    public var scope: VocalCreativeScope
    public var exactCandidateID: UUID
    public var exactPlanRequestID: UUID
    public var exactNodeIDs: [UUID]
    public var parentPreviewID: UUID?
    public var parentAssetID: UUID?
    public var assetAncestry: [UUID]
    public var engine: VocalEngineIdentity
    public var processingPlan: ProcessingPlan
    public var randomSeed: UInt64?
    public var createdAt: Date
    public var limitations: [String]
    public var localOffline: Bool
    public var usesNetwork: Bool
    public var thirdPartyMaterialStatus: VocalThirdPartyMaterialStatus
    public var outsideScopePreservedExactly: Bool
    public var crossfadeFrames: Int
    public var renderedPeakLinear: Double
    public var boundaryDecision: VocalBoundaryDecision

    public init(
        version: VocalSchemaVersion = .v1,
        renderID: UUID,
        renderHashSHA256: String,
        sourceAuthority: VocalSourceAuthority,
        originalPrompt: String,
        typedIntent: VocalCreativeIntent,
        preservation: VocalPreservationContract,
        scope: VocalCreativeScope,
        exactCandidateID: UUID,
        exactPlanRequestID: UUID,
        exactNodeIDs: [UUID],
        parentPreviewID: UUID?,
        parentAssetID: UUID?,
        assetAncestry: [UUID],
        engine: VocalEngineIdentity,
        processingPlan: ProcessingPlan,
        randomSeed: UInt64?,
        createdAt: Date,
        limitations: [String],
        localOffline: Bool,
        usesNetwork: Bool,
        thirdPartyMaterialStatus: VocalThirdPartyMaterialStatus,
        outsideScopePreservedExactly: Bool,
        crossfadeFrames: Int,
        renderedPeakLinear: Double,
        boundaryDecision: VocalBoundaryDecision
    ) {
        self.version = version
        self.renderID = renderID
        self.renderHashSHA256 = renderHashSHA256
        self.sourceAuthority = sourceAuthority
        self.originalPrompt = originalPrompt
        self.typedIntent = typedIntent
        self.preservation = preservation
        self.scope = scope
        self.exactCandidateID = exactCandidateID
        self.exactPlanRequestID = exactPlanRequestID
        self.exactNodeIDs = exactNodeIDs
        self.parentPreviewID = parentPreviewID
        self.parentAssetID = parentAssetID
        self.assetAncestry = assetAncestry
        self.engine = engine
        self.processingPlan = processingPlan
        self.randomSeed = randomSeed
        self.createdAt = createdAt
        self.limitations = limitations
        self.localOffline = localOffline
        self.usesNetwork = usesNetwork
        self.thirdPartyMaterialStatus = thirdPartyMaterialStatus
        self.outsideScopePreservedExactly = outsideScopePreservedExactly
        self.crossfadeFrames = crossfadeFrames
        self.renderedPeakLinear = renderedPeakLinear
        self.boundaryDecision = boundaryDecision
    }
}

public struct VocalRenderedAsset: Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var audio: AudioBuffer
    public var manifest: VocalRenderedAssetManifest

    public init(
        version: VocalSchemaVersion = .v1,
        audio: AudioBuffer,
        manifest: VocalRenderedAssetManifest
    ) {
        self.version = version
        self.audio = audio
        self.manifest = manifest
    }
}

public enum VocalRenderError: Error, Equatable, CustomStringConvertible, Sendable {
    case staleSourceSnapshot(expected: UUID, actual: UUID)
    case staleSourceHash(expected: String, actual: String)
    case changedFormat(String)
    case changedScope(String)
    case scopeOutsideSource
    case unsupportedAssetPermission(VocalAssetAcceptance)
    case unsupportedThirdPartyMaterial(VocalThirdPartyMaterialStatus)
    case lockConflict(VocalAspect)
    case missingLockedNode(UUID)
    case invalidCrossfade(Double)
    case nonfiniteInput(channel: Int, frame: Int)
    case nonfiniteOutput(channel: Int, frame: Int)
    case unsafeSourcePeak(Double)
    case unsafeRenderedPeak(actual: Double, allowed: Double)
    case sourcePreservationFailure
    case planValidation(String)
    case dsp(String)

    public var description: String {
        switch self {
        case let .staleSourceSnapshot(expected, actual): "Render expects source snapshot \(expected), received \(actual)."
        case let .staleSourceHash(expected, actual): "Render source hash changed; expected \(expected), received \(actual)."
        case let .changedFormat(reason): "Render source format changed: \(reason)"
        case let .changedScope(reason): "Render scope authority changed: \(reason)"
        case .scopeOutsideSource: "The exact vocal scope lies outside the supplied source buffer."
        case let .unsupportedAssetPermission(permission): "Typed asset permission \(permission.rawValue) does not authorize rendering."
        case let .unsupportedThirdPartyMaterial(status): "Vocal v1 local rendering does not accept third-party material status \(status.rawValue)."
        case let .lockConflict(aspect): "Render candidate conflicts with the exact \(aspect.rawValue) lock."
        case let .missingLockedNode(id): "Render candidate is missing locked node \(id)."
        case let .invalidCrossfade(value): "Crossfade \(value) seconds must be finite and inside 0...0.1."
        case let .nonfiniteInput(channel, frame): "Nonfinite source sample at channel \(channel), frame \(frame)."
        case let .nonfiniteOutput(channel, frame): "Nonfinite rendered sample at channel \(channel), frame \(frame)."
        case let .unsafeSourcePeak(value): "Source sample peak \(value) reaches or exceeds digital full scale; rendering is refused until capture safety is resolved."
        case let .unsafeRenderedPeak(actual, allowed): "Rendered sample peak \(actual) exceeds allowed peak \(allowed)."
        case .sourcePreservationFailure: "The immutable source changed during off-render processing."
        case let .planValidation(reason): "Render plan validation failed: \(reason)"
        case let .dsp(reason): "Vocal DSP render failed: \(reason)"
        }
    }
}

public struct VocalAudioHasher: Sendable {
    public init() {}

    public func sha256(_ buffer: AudioBuffer) throws -> String {
        var data = Data()
        data.reserveCapacity(32 + buffer.channelCount * buffer.frameCount * MemoryLayout<UInt32>.size)
        append(UInt64(buffer.sampleRate.bitPattern).littleEndian, to: &data)
        append(UInt64(buffer.channelCount).littleEndian, to: &data)
        append(UInt64(buffer.frameCount).littleEndian, to: &data)
        for (channelIndex, channel) in buffer.channels.enumerated() {
            append(UInt64(channelIndex).littleEndian, to: &data)
            for (frameIndex, sample) in channel.enumerated() {
                guard sample.isFinite else {
                    throw VocalRenderError.nonfiniteInput(channel: channelIndex, frame: frameIndex)
                }
                append(sample.bitPattern.littleEndian, to: &data)
            }
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func authority(
        for buffer: AudioBuffer,
        sourceSnapshotID: UUID,
        immutableSourceID: String,
        capturedAt: Date
    ) throws -> VocalSourceAuthority {
        VocalSourceAuthority(
            sourceSnapshotID: sourceSnapshotID,
            immutableSourceID: immutableSourceID,
            contentHashSHA256: try sha256(buffer),
            sampleRate: buffer.sampleRate,
            channelCount: buffer.channelCount,
            frameCount: buffer.frameCount,
            capturedAt: capturedAt
        )
    }

    private func append<T>(_ value: T, to data: inout Data) {
        var copy = value
        withUnsafeBytes(of: &copy) { bytes in data.append(contentsOf: bytes) }
    }
}

public struct VocalScopedAssetRenderer: Sendable {
    public init() {}

    public func render(
        source: AudioBuffer,
        request: VocalScopedRenderRequest
    ) throws -> VocalRenderedAsset {
        let candidate = request.candidate
        let intent = candidate.intent
        let boundary = VocalProcessingBoundaryEvaluator().decision(for: intent)
        guard request.engine == .trackSmithVocalV1 else {
            throw VocalRenderError.planValidation(
                "The requested engine/pipeline identity is not implemented by this TrackSmith-owned renderer."
            )
        }
        guard intent.assetAcceptance == .allowLocalRenderedAsset
                || intent.assetAcceptance == .requireLocalRenderedAsset else {
            throw VocalRenderError.unsupportedAssetPermission(intent.assetAcceptance)
        }
        guard request.thirdPartyMaterialStatus == .noneUsed else {
            throw VocalRenderError.unsupportedThirdPartyMaterial(request.thirdPartyMaterialStatus)
        }
        let effectiveParentAssetID = request.parentAssetID ?? candidate.assetID
        guard !request.assetAncestry.contains(request.renderID),
              Set(request.assetAncestry).count == request.assetAncestry.count,
              effectiveParentAssetID.map({ request.assetAncestry.contains($0) }) ?? true else {
            throw VocalRenderError.planValidation(
                "Asset ancestry must be acyclic, unique, and contain the exact parent asset when one is supplied."
            )
        }
        guard request.crossfadeSeconds.isFinite, (0...0.1).contains(request.crossfadeSeconds) else {
            throw VocalRenderError.invalidCrossfade(request.crossfadeSeconds)
        }
        guard candidate.plan.sourceSnapshotID == request.sourceAuthority.sourceSnapshotID,
              intent.sourceSnapshotID == request.sourceAuthority.sourceSnapshotID else {
            throw VocalRenderError.staleSourceSnapshot(
                expected: request.sourceAuthority.sourceSnapshotID,
                actual: candidate.plan.sourceSnapshotID
            )
        }
        guard source.sampleRate == request.sourceAuthority.sampleRate else {
            throw VocalRenderError.changedFormat(
                "expected \(request.sourceAuthority.sampleRate) Hz, received \(source.sampleRate) Hz"
            )
        }
        guard source.channelCount == request.sourceAuthority.channelCount else {
            throw VocalRenderError.changedFormat(
                "expected \(request.sourceAuthority.channelCount) channels, received \(source.channelCount)"
            )
        }
        guard source.frameCount == request.sourceAuthority.frameCount else {
            throw VocalRenderError.changedFormat(
                "expected \(request.sourceAuthority.frameCount) frames, received \(source.frameCount)"
            )
        }
        let channelFormat: ChannelFormat = source.channelCount == 1 ? .mono : .stereo
        guard candidate.plan.scope.channelFormat == channelFormat else {
            throw VocalRenderError.changedFormat("plan and source channel formats disagree")
        }
        let exactRange = intent.scope.kind == .fullSource ? nil : intent.scope.seconds
        guard candidate.plan.scope.timeRangeSeconds == exactRange else {
            throw VocalRenderError.changedScope("typed intent and ProcessingPlan ranges disagree")
        }
        try validateLocks(candidate)
        do {
            try VocalContractValidator().validate(candidate: candidate)
            if candidate.realtimeActivatable {
                try PlanValidator().validateForRealtimeActivation(
                    candidate.plan,
                    currentSnapshotID: request.sourceAuthority.sourceSnapshotID
                )
            } else {
                try PlanValidator().validate(
                    candidate.plan,
                    currentSnapshotID: request.sourceAuthority.sourceSnapshotID
                )
            }
        } catch {
            throw VocalRenderError.planValidation(String(describing: error))
        }

        let hasher = VocalAudioHasher()
        let sourceHash = try hasher.sha256(source)
        guard sourceHash == request.sourceAuthority.contentHashSHA256.lowercased() else {
            throw VocalRenderError.staleSourceHash(
                expected: request.sourceAuthority.contentHashSHA256.lowercased(),
                actual: sourceHash
            )
        }
        let sourcePeak = try peakAndValidateFinite(source, input: true)
        guard sourcePeak < 1.0 else { throw VocalRenderError.unsafeSourcePeak(sourcePeak) }

        let frameRange = try resolveFrameRange(
            intent.scope,
            frameCount: source.frameCount,
            sampleRate: source.sampleRate
        )
        var processed = source
        do {
            var graph = try CompiledGraph(
                plan: candidate.plan,
                sampleRate: source.sampleRate,
                channelCount: source.channelCount
            )
            try graph.process(&processed)
        } catch {
            throw VocalRenderError.dsp(String(describing: error))
        }

        let output: AudioBuffer
        let crossfadeFrames: Int
        if let frameRange {
            var blended = source
            let roundedFrames = Int((request.crossfadeSeconds * source.sampleRate).rounded())
            let requestedFrames = request.crossfadeSeconds == 0 ? 0 : max(1, roundedFrames)
            guard requestedFrames == 0 || frameRange.count >= 2 else {
                throw VocalRenderError.changedScope(
                    "bounded scope is too short for the requested deterministic crossfade"
                )
            }
            crossfadeFrames = min(max(0, requestedFrames), frameRange.count / 2)
            for channel in blended.channels.indices {
                for frame in frameRange {
                    let offset = frame - frameRange.lowerBound
                    let remaining = frameRange.upperBound - 1 - frame
                    var wet = 1.0
                    if crossfadeFrames > 0 {
                        let fadeIn = min(1, Double(offset + 1) / Double(crossfadeFrames + 1))
                        let fadeOut = min(1, Double(remaining + 1) / Double(crossfadeFrames + 1))
                        wet = min(fadeIn, fadeOut)
                    }
                    let drySample = source.channels[channel][frame]
                    let wetSample = processed.channels[channel][frame]
                    blended.channels[channel][frame] = drySample + Float(wet) * (wetSample - drySample)
                }
            }
            try verifyOutsideScope(source: source, output: blended, range: frameRange)
            output = blended
        } else {
            crossfadeFrames = 0
            output = processed
        }

        guard try hasher.sha256(source) == sourceHash else {
            throw VocalRenderError.sourcePreservationFailure
        }
        let renderedPeak = try peakAndValidateFinite(output, input: false)
        let limiterAllowed = pow(10, candidate.plan.outputConstraints.maxTruePeakDB / 20)
        let allowedPeak = frameRange == nil ? limiterAllowed : min(1, max(limiterAllowed, sourcePeak))
        guard renderedPeak <= allowedPeak + 1e-5 else {
            throw VocalRenderError.unsafeRenderedPeak(actual: renderedPeak, allowed: allowedPeak)
        }
        let renderHash = try hasher.sha256(output)
        let manifest = VocalRenderedAssetManifest(
            renderID: request.renderID,
            renderHashSHA256: renderHash,
            sourceAuthority: request.sourceAuthority,
            originalPrompt: intent.originalPrompt,
            typedIntent: intent,
            preservation: intent.preservation,
            scope: intent.scope,
            exactCandidateID: candidate.id,
            exactPlanRequestID: candidate.plan.requestID,
            exactNodeIDs: candidate.plan.nodes.map(\.id),
            parentPreviewID: request.parentPreviewID ?? candidate.previewID,
            parentAssetID: request.parentAssetID ?? candidate.assetID,
            assetAncestry: request.assetAncestry,
            engine: request.engine,
            processingPlan: candidate.plan,
            randomSeed: request.randomSeed,
            createdAt: request.createdAt,
            limitations: candidate.limitations + [
                "Rendering is local/offline and uses only TrackSmith-owned deterministic DSP; no provider, network, third-party model, or Logic automation is involved.",
                "For bounded scope, samples outside the exact frame range are bit-for-bit unchanged and short deterministic crossfades occur only inside the scope.",
                "A whole-source editable plan could remain a plan instead of becoming an asset; this manifest records the caller's explicit asset permission.",
                "The limiter is sample-peak protection, not a formally verified true-peak guarantee.",
            ],
            localOffline: true,
            usesNetwork: false,
            thirdPartyMaterialStatus: .noneUsed,
            outsideScopePreservedExactly: frameRange != nil,
            crossfadeFrames: crossfadeFrames,
            renderedPeakLinear: renderedPeak,
            boundaryDecision: boundary
        )
        return VocalRenderedAsset(audio: output, manifest: manifest)
    }

    private func validateLocks(_ candidate: VocalCreativeCandidate) throws {
        let nodeIDs = Set(candidate.plan.nodes.map(\.id))
        let nodesByID = Dictionary(uniqueKeysWithValues: candidate.plan.nodes.map { ($0.id, $0) })
        for lock in candidate.intent.aspectLocks {
            guard lock.reference.sourceSnapshotID == candidate.intent.sourceSnapshotID,
                  lock.reference.scopeID == candidate.intent.scope.id || lock.scopePolicy == .contentRelative else {
                throw VocalRenderError.lockConflict(lock.aspect)
            }
            for nodeID in lock.reference.nodeIDs where !nodeIDs.contains(nodeID) {
                throw VocalRenderError.missingLockedNode(nodeID)
            }
            for exactNode in lock.exactNodes where nodesByID[exactNode.id] != exactNode {
                throw VocalRenderError.lockConflict(lock.aspect)
            }
        }
    }

    private func resolveFrameRange(
        _ scope: VocalCreativeScope,
        frameCount: Int,
        sampleRate: Double
    ) throws -> Range<Int>? {
        guard scope.kind != .fullSource else { return nil }
        guard let seconds = scope.seconds else { throw VocalRenderError.changedScope("bounded scope has no range") }
        let lowerDouble = seconds.start * sampleRate
        let upperDouble = seconds.end * sampleRate
        guard lowerDouble.isFinite, upperDouble.isFinite else { throw VocalRenderError.scopeOutsideSource }
        let lower = Int(lowerDouble.rounded(.down))
        let upper = Int(upperDouble.rounded(.up))
        guard lower >= 0, upper <= frameCount, upper > lower else {
            throw VocalRenderError.scopeOutsideSource
        }
        return lower..<upper
    }

    private func peakAndValidateFinite(
        _ buffer: AudioBuffer,
        input: Bool
    ) throws -> Double {
        var peak = 0.0
        for (channelIndex, channel) in buffer.channels.enumerated() {
            for (frameIndex, sample) in channel.enumerated() {
                guard sample.isFinite else {
                    if input {
                        throw VocalRenderError.nonfiniteInput(channel: channelIndex, frame: frameIndex)
                    }
                    throw VocalRenderError.nonfiniteOutput(channel: channelIndex, frame: frameIndex)
                }
                peak = max(peak, abs(Double(sample)))
            }
        }
        return peak
    }

    private func verifyOutsideScope(
        source: AudioBuffer,
        output: AudioBuffer,
        range: Range<Int>
    ) throws {
        for channel in source.channels.indices {
            for frame in 0..<range.lowerBound where source.channels[channel][frame].bitPattern != output.channels[channel][frame].bitPattern {
                throw VocalRenderError.sourcePreservationFailure
            }
            if range.upperBound < source.frameCount {
                for frame in range.upperBound..<source.frameCount where source.channels[channel][frame].bitPattern != output.channels[channel][frame].bitPattern {
                    throw VocalRenderError.sourcePreservationFailure
                }
            }
        }
    }
}
