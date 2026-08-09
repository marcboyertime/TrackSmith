import Foundation

/// The only execution locations permitted for the TrackSmith-owned audio-to-MIDI boundary.
/// Inference and proposal generation are deliberately unavailable to an AU render callback.
public enum AudioToMIDIExecutionBoundary: String, Codable, CaseIterable, Sendable {
    case companionOffRenderWorker = "companion_off_render_worker"
    case offlineCLI = "offline_cli"
}

public struct AudioSourceIdentity: Codable, Equatable, Sendable {
    public var sourceID: String
    public var captureID: String
    public var audioSHA256: String

    public init(sourceID: String, captureID: String, audioSHA256: String) {
        self.sourceID = sourceID
        self.captureID = captureID
        self.audioSHA256 = audioSHA256
    }
}

public struct ExistingMIDIIdentity: Codable, Equatable, Sendable {
    public var midiID: String
    public var midiSHA256: String

    public init(midiID: String, midiSHA256: String) {
        self.midiID = midiID
        self.midiSHA256 = midiSHA256
    }
}

public struct AudioFormatMetadata: Codable, Equatable, Sendable {
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64

    public init(sampleRate: Double, channelCount: Int, frameCount: Int64) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
    }

    public var durationSeconds: Double {
        guard sampleRate.isFinite, sampleRate > 0 else { return 0 }
        return Double(frameCount) / sampleRate
    }
}

/// Identifies a locally selected, versioned proposal implementation. This does not grant the
/// implementation authority to choose executable code, DSP graphs, or arbitrary parameters.
public struct AudioToMIDIAlgorithmIdentity: Codable, Equatable, Sendable {
    public var implementationOwner: String
    public var algorithmIdentifier: String
    public var algorithmVersion: String
    public var modelIdentifier: String?
    public var modelDigestSHA256: String?

    public init(
        implementationOwner: String,
        algorithmIdentifier: String,
        algorithmVersion: String,
        modelIdentifier: String? = nil,
        modelDigestSHA256: String? = nil
    ) {
        self.implementationOwner = implementationOwner
        self.algorithmIdentifier = algorithmIdentifier
        self.algorithmVersion = algorithmVersion
        self.modelIdentifier = modelIdentifier
        self.modelDigestSHA256 = modelDigestSHA256
    }
}

/// A proposal request is immutable and bound to one exact source revision and capture identity.
public struct AudioToMIDIRequest: Codable, Equatable, Sendable {
    public static let schemaVersion = "1.0.0"

    public var schemaVersion: String
    public var requestID: String
    public var sourceRevision: UInt64
    public var replaySeed: UInt64
    public var sourceAudio: AudioSourceIdentity
    public var existingMIDI: ExistingMIDIIdentity?
    public var format: AudioFormatMetadata
    public var algorithm: AudioToMIDIAlgorithmIdentity
    public var executionBoundary: AudioToMIDIExecutionBoundary
    public var localProcessingRequired: Bool
    public var networkAccessAllowed: Bool
    public var renderThreadExecutionAllowed: Bool

    public init(
        requestID: String,
        sourceRevision: UInt64,
        replaySeed: UInt64,
        sourceAudio: AudioSourceIdentity,
        existingMIDI: ExistingMIDIIdentity? = nil,
        format: AudioFormatMetadata,
        algorithm: AudioToMIDIAlgorithmIdentity,
        executionBoundary: AudioToMIDIExecutionBoundary,
        localProcessingRequired: Bool = true,
        networkAccessAllowed: Bool = false,
        renderThreadExecutionAllowed: Bool = false
    ) {
        self.schemaVersion = Self.schemaVersion
        self.requestID = requestID
        self.sourceRevision = sourceRevision
        self.replaySeed = replaySeed
        self.sourceAudio = sourceAudio
        self.existingMIDI = existingMIDI
        self.format = format
        self.algorithm = algorithm
        self.executionBoundary = executionBoundary
        self.localProcessingRequired = localProcessingRequired
        self.networkAccessAllowed = networkAccessAllowed
        self.renderThreadExecutionAllowed = renderThreadExecutionAllowed
    }
}

/// A bounded musical suggestion. It is never applied automatically and contains no DSP or code.
public struct MIDINoteProposal: Codable, Equatable, Sendable {
    public var proposalID: String
    public var pitch: Int
    public var startSeconds: Double
    public var durationSeconds: Double
    public var confidence: Double
    public var velocity: Int
    public var channel: Int

    public init(
        proposalID: String,
        pitch: Int,
        startSeconds: Double,
        durationSeconds: Double,
        confidence: Double,
        velocity: Int,
        channel: Int = 0
    ) {
        self.proposalID = proposalID
        self.pitch = pitch
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
        self.confidence = confidence
        self.velocity = velocity
        self.channel = channel
    }
}

/// Required evidence that proposal generation did not replace or mutate source artifacts.
public struct AudioToMIDISourcePreservation: Codable, Equatable, Sendable {
    public var originalAudioUnmodified: Bool
    public var originalMIDIUnmodified: Bool
    public var outputIsProposalOnly: Bool
    public var destinationIsolatedFromSources: Bool
    public var preservedAudioSHA256: String
    public var preservedMIDISHA256: String?

    public init(
        originalAudioUnmodified: Bool,
        originalMIDIUnmodified: Bool,
        outputIsProposalOnly: Bool,
        destinationIsolatedFromSources: Bool,
        preservedAudioSHA256: String,
        preservedMIDISHA256: String? = nil
    ) {
        self.originalAudioUnmodified = originalAudioUnmodified
        self.originalMIDIUnmodified = originalMIDIUnmodified
        self.outputIsProposalOnly = outputIsProposalOnly
        self.destinationIsolatedFromSources = destinationIsolatedFromSources
        self.preservedAudioSHA256 = preservedAudioSHA256
        self.preservedMIDISHA256 = preservedMIDISHA256
    }
}

public struct AudioToMIDIProvenance: Codable, Equatable, Sendable {
    public var requestID: String
    public var requestFingerprint: String
    public var sourceID: String
    public var captureID: String
    public var sourceAudioSHA256: String
    public var sourceRevision: UInt64
    public var replaySeed: UInt64
    public var format: AudioFormatMetadata
    public var algorithm: AudioToMIDIAlgorithmIdentity
    public var executionBoundary: AudioToMIDIExecutionBoundary
    public var generatedLocally: Bool
    public var networkAccessed: Bool
    public var renderThreadUsed: Bool
    public var syntheticFixture: Bool

    public init(
        requestID: String,
        requestFingerprint: String,
        sourceID: String,
        captureID: String,
        sourceAudioSHA256: String,
        sourceRevision: UInt64,
        replaySeed: UInt64,
        format: AudioFormatMetadata,
        algorithm: AudioToMIDIAlgorithmIdentity,
        executionBoundary: AudioToMIDIExecutionBoundary,
        generatedLocally: Bool,
        networkAccessed: Bool,
        renderThreadUsed: Bool,
        syntheticFixture: Bool
    ) {
        self.requestID = requestID
        self.requestFingerprint = requestFingerprint
        self.sourceID = sourceID
        self.captureID = captureID
        self.sourceAudioSHA256 = sourceAudioSHA256
        self.sourceRevision = sourceRevision
        self.replaySeed = replaySeed
        self.format = format
        self.algorithm = algorithm
        self.executionBoundary = executionBoundary
        self.generatedLocally = generatedLocally
        self.networkAccessed = networkAccessed
        self.renderThreadUsed = renderThreadUsed
        self.syntheticFixture = syntheticFixture
    }
}

public struct AudioToMIDIProposalSet: Codable, Equatable, Sendable {
    public static let schemaVersion = "1.0.0"

    public var schemaVersion: String
    public var notes: [MIDINoteProposal]
    public var preservation: AudioToMIDISourcePreservation
    public var provenance: AudioToMIDIProvenance
    /// FNV-1a is used only as a deterministic replay checksum. Artifact identities remain SHA-256.
    public var replayChecksum: String

    public init(
        notes: [MIDINoteProposal],
        preservation: AudioToMIDISourcePreservation,
        provenance: AudioToMIDIProvenance,
        replayChecksum: String
    ) {
        self.schemaVersion = Self.schemaVersion
        self.notes = notes
        self.preservation = preservation
        self.provenance = provenance
        self.replayChecksum = replayChecksum
    }
}

public enum AudioToMIDIValidationError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalid(String)

    public var description: String {
        switch self {
        case let .invalid(reason): reason
        }
    }
}

public struct AudioToMIDIValidator: Sendable {
    public static let maximumNotes = 4_096
    public static let maximumUntrustedPayloadBytes = 2 * 1_024 * 1_024

    private let allowedAlgorithmIdentifiers: Set<String>

    public init(allowedAlgorithmIdentifiers: Set<String>) {
        self.allowedAlgorithmIdentifiers = allowedAlgorithmIdentifiers
    }

    public func validate(request: AudioToMIDIRequest) throws {
        guard request.schemaVersion == AudioToMIDIRequest.schemaVersion else {
            throw AudioToMIDIValidationError.invalid("Unsupported request schema version.")
        }
        try Self.requireBoundedIdentifier(request.requestID, field: "requestID")
        try Self.validate(source: request.sourceAudio)
        if let midi = request.existingMIDI {
            try Self.requireBoundedIdentifier(midi.midiID, field: "midiID")
            try Self.requireSHA256(midi.midiSHA256, field: "midiSHA256")
        }
        guard request.format.sampleRate.isFinite,
              (8_000...384_000).contains(request.format.sampleRate),
              (1...64).contains(request.format.channelCount),
              request.format.frameCount > 0,
              request.format.frameCount <= 4_294_967_296,
              request.format.durationSeconds.isFinite,
              request.format.durationSeconds <= 86_400 else {
            throw AudioToMIDIValidationError.invalid("Audio format metadata is outside bounded limits.")
        }
        try validate(algorithm: request.algorithm)
        guard allowedAlgorithmIdentifiers.contains(request.algorithm.algorithmIdentifier) else {
            throw AudioToMIDIValidationError.invalid("The requested algorithm is not locally allowlisted.")
        }
        guard request.localProcessingRequired,
              !request.networkAccessAllowed,
              !request.renderThreadExecutionAllowed else {
            throw AudioToMIDIValidationError.invalid(
                "Audio-to-MIDI must remain local, network-free, and outside the render callback."
            )
        }
    }

    public func validate(
        proposalSet: AudioToMIDIProposalSet,
        for request: AudioToMIDIRequest,
        currentSourceRevision: UInt64
    ) throws {
        try validate(request: request)
        guard currentSourceRevision == request.sourceRevision else {
            throw AudioToMIDIValidationError.invalid("The request is stale for the current source revision.")
        }
        guard proposalSet.schemaVersion == AudioToMIDIProposalSet.schemaVersion else {
            throw AudioToMIDIValidationError.invalid("Unsupported proposal schema version.")
        }
        let provenance = proposalSet.provenance
        guard provenance.requestID == request.requestID,
              provenance.requestFingerprint == Self.requestFingerprint(request),
              provenance.sourceID == request.sourceAudio.sourceID,
              provenance.captureID == request.sourceAudio.captureID,
              provenance.sourceAudioSHA256 == request.sourceAudio.audioSHA256,
              provenance.sourceRevision == request.sourceRevision,
              provenance.replaySeed == request.replaySeed,
              provenance.format == request.format,
              provenance.algorithm == request.algorithm,
              provenance.executionBoundary == request.executionBoundary else {
            throw AudioToMIDIValidationError.invalid("Proposal provenance does not match its request.")
        }
        guard provenance.generatedLocally,
              !provenance.networkAccessed,
              !provenance.renderThreadUsed else {
            throw AudioToMIDIValidationError.invalid("Proposal provenance violates its execution boundary.")
        }

        let preservation = proposalSet.preservation
        guard preservation.originalAudioUnmodified,
              preservation.originalMIDIUnmodified,
              preservation.outputIsProposalOnly,
              preservation.destinationIsolatedFromSources,
              preservation.preservedAudioSHA256 == request.sourceAudio.audioSHA256,
              preservation.preservedMIDISHA256 == request.existingMIDI?.midiSHA256 else {
            throw AudioToMIDIValidationError.invalid("Source preservation proof is missing or mismatched.")
        }
        guard proposalSet.notes.count <= Self.maximumNotes else {
            throw AudioToMIDIValidationError.invalid("The proposal note count exceeds the fixed bound.")
        }

        var priorSortKey: (Double, Int, String)?
        var identifiers = Set<String>()
        for note in proposalSet.notes {
            try Self.requireBoundedIdentifier(note.proposalID, field: "proposalID")
            guard identifiers.insert(note.proposalID).inserted else {
                throw AudioToMIDIValidationError.invalid("Proposal identifiers must be unique.")
            }
            guard (0...127).contains(note.pitch),
                  note.startSeconds.isFinite,
                  note.durationSeconds.isFinite,
                  note.confidence.isFinite,
                  note.startSeconds >= 0,
                  note.durationSeconds > 0,
                  note.startSeconds + note.durationSeconds <= request.format.durationSeconds + 0.000_001,
                  (0...1).contains(note.confidence),
                  (1...127).contains(note.velocity),
                  (0...15).contains(note.channel) else {
                throw AudioToMIDIValidationError.invalid("A note proposal is non-finite or outside bounded limits.")
            }
            let key = (note.startSeconds, note.pitch, note.proposalID)
            if let priorSortKey, Self.isOrderedAfter(priorSortKey, key) {
                throw AudioToMIDIValidationError.invalid("Note proposals are not in deterministic order.")
            }
            priorSortKey = key
        }

        let expectedChecksum = Self.replayChecksum(
            notes: proposalSet.notes,
            preservation: proposalSet.preservation,
            provenance: proposalSet.provenance
        )
        guard proposalSet.replayChecksum == expectedChecksum else {
            throw AudioToMIDIValidationError.invalid("The deterministic replay checksum does not match.")
        }
    }

    /// Strict decoding for untrusted worker output. Unknown fields are rejected before Codable
    /// decoding so provider output cannot smuggle executable, DSP, or arbitrary parameter keys.
    public func decodeAndValidateUntrusted(
        _ data: Data,
        for request: AudioToMIDIRequest,
        currentSourceRevision: UInt64
    ) throws -> AudioToMIDIProposalSet {
        guard data.count <= Self.maximumUntrustedPayloadBytes else {
            throw AudioToMIDIValidationError.invalid("The untrusted proposal payload is oversized.")
        }
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let root = raw as? [String: Any] else {
            throw AudioToMIDIValidationError.invalid("The untrusted proposal payload is not an object.")
        }
        try Self.rejectUnknownKeys(
            root,
            allowed: ["schemaVersion", "notes", "preservation", "provenance", "replayChecksum"],
            context: "proposal"
        )
        guard let notes = root["notes"] as? [[String: Any]],
              let preservation = root["preservation"] as? [String: Any],
              let provenance = root["provenance"] as? [String: Any] else {
            throw AudioToMIDIValidationError.invalid("The untrusted proposal payload has invalid structure.")
        }
        guard notes.count <= Self.maximumNotes else {
            throw AudioToMIDIValidationError.invalid("The untrusted proposal note count exceeds the fixed bound.")
        }
        for note in notes {
            try Self.rejectUnknownKeys(
                note,
                allowed: ["proposalID", "pitch", "startSeconds", "durationSeconds", "confidence", "velocity", "channel"],
                context: "note"
            )
        }
        try Self.rejectUnknownKeys(
            preservation,
            allowed: [
                "originalAudioUnmodified", "originalMIDIUnmodified", "outputIsProposalOnly",
                "destinationIsolatedFromSources", "preservedAudioSHA256", "preservedMIDISHA256"
            ],
            context: "preservation"
        )
        try Self.rejectUnknownKeys(
            provenance,
            allowed: [
                "requestID", "requestFingerprint", "sourceID", "captureID", "sourceAudioSHA256",
                "sourceRevision", "replaySeed", "format", "algorithm", "executionBoundary", "generatedLocally",
                "networkAccessed", "renderThreadUsed", "syntheticFixture"
            ],
            context: "provenance"
        )
        if let format = provenance["format"] as? [String: Any] {
            try Self.rejectUnknownKeys(
                format,
                allowed: ["sampleRate", "channelCount", "frameCount"],
                context: "format"
            )
        } else {
            throw AudioToMIDIValidationError.invalid("The proposal audio format is missing.")
        }
        if let algorithm = provenance["algorithm"] as? [String: Any] {
            try Self.rejectUnknownKeys(
                algorithm,
                allowed: [
                    "implementationOwner", "algorithmIdentifier", "algorithmVersion",
                    "modelIdentifier", "modelDigestSHA256"
                ],
                context: "algorithm"
            )
        } else {
            throw AudioToMIDIValidationError.invalid("The proposal algorithm identity is missing.")
        }

        let decoded: AudioToMIDIProposalSet
        do {
            decoded = try JSONDecoder().decode(AudioToMIDIProposalSet.self, from: data)
        } catch {
            throw AudioToMIDIValidationError.invalid("The untrusted proposal payload could not be decoded.")
        }
        try validate(proposalSet: decoded, for: request, currentSourceRevision: currentSourceRevision)
        return decoded
    }

    public static func replayChecksum(
        notes: [MIDINoteProposal],
        preservation: AudioToMIDISourcePreservation,
        provenance: AudioToMIDIProvenance
    ) -> String {
        let noteText = notes.map {
            [
                $0.proposalID,
                String($0.pitch),
                canonicalDouble($0.startSeconds),
                canonicalDouble($0.durationSeconds),
                canonicalDouble($0.confidence),
                String($0.velocity),
                String($0.channel)
            ].joined(separator: "|")
        }.joined(separator: ";")
        let fields = [
            provenance.requestID,
            provenance.requestFingerprint,
            provenance.sourceID,
            provenance.captureID,
            provenance.sourceAudioSHA256,
            String(provenance.sourceRevision),
            String(provenance.replaySeed),
            canonicalDouble(provenance.format.sampleRate),
            String(provenance.format.channelCount),
            String(provenance.format.frameCount),
            provenance.algorithm.implementationOwner,
            provenance.algorithm.algorithmIdentifier,
            provenance.algorithm.algorithmVersion,
            provenance.algorithm.modelIdentifier ?? "-",
            provenance.algorithm.modelDigestSHA256 ?? "-",
            provenance.executionBoundary.rawValue,
            String(provenance.generatedLocally),
            String(provenance.networkAccessed),
            String(provenance.renderThreadUsed),
            String(provenance.syntheticFixture),
            String(preservation.originalAudioUnmodified),
            String(preservation.originalMIDIUnmodified),
            String(preservation.outputIsProposalOnly),
            String(preservation.destinationIsolatedFromSources),
            preservation.preservedAudioSHA256,
            preservation.preservedMIDISHA256 ?? "-",
            noteText
        ]
        return "fnv1a64:" + StableFNV1a.hex(fields.joined(separator: "\u{1f}"))
    }

    public static func requestFingerprint(_ request: AudioToMIDIRequest) -> String {
        let fields = [
            request.schemaVersion,
            request.requestID,
            String(request.sourceRevision),
            String(request.replaySeed),
            request.sourceAudio.sourceID,
            request.sourceAudio.captureID,
            request.sourceAudio.audioSHA256,
            request.existingMIDI?.midiID ?? "-",
            request.existingMIDI?.midiSHA256 ?? "-",
            canonicalDouble(request.format.sampleRate),
            String(request.format.channelCount),
            String(request.format.frameCount),
            request.algorithm.implementationOwner,
            request.algorithm.algorithmIdentifier,
            request.algorithm.algorithmVersion,
            request.algorithm.modelIdentifier ?? "-",
            request.algorithm.modelDigestSHA256 ?? "-",
            request.executionBoundary.rawValue,
            String(request.localProcessingRequired),
            String(request.networkAccessAllowed),
            String(request.renderThreadExecutionAllowed),
        ]
        return "fnv1a64:" + StableFNV1a.hex(fields.joined(separator: "\u{1f}"))
    }

    private func validate(algorithm: AudioToMIDIAlgorithmIdentity) throws {
        try Self.requireBoundedIdentifier(algorithm.implementationOwner, field: "implementationOwner")
        try Self.requireBoundedIdentifier(algorithm.algorithmIdentifier, field: "algorithmIdentifier")
        try Self.requireBoundedIdentifier(algorithm.algorithmVersion, field: "algorithmVersion")
        if let modelIdentifier = algorithm.modelIdentifier {
            try Self.requireBoundedIdentifier(modelIdentifier, field: "modelIdentifier")
            guard let digest = algorithm.modelDigestSHA256 else {
                throw AudioToMIDIValidationError.invalid("A model identity requires a pinned SHA-256 digest.")
            }
            try Self.requireSHA256(digest, field: "modelDigestSHA256")
        } else if algorithm.modelDigestSHA256 != nil {
            throw AudioToMIDIValidationError.invalid("A model digest cannot appear without a model identity.")
        }
    }

    private static func validate(source: AudioSourceIdentity) throws {
        try requireBoundedIdentifier(source.sourceID, field: "sourceID")
        try requireBoundedIdentifier(source.captureID, field: "captureID")
        try requireSHA256(source.audioSHA256, field: "audioSHA256")
    }

    private static func requireBoundedIdentifier(_ value: String, field: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == value,
              !value.isEmpty,
              value.utf8.count <= 128,
              value.unicodeScalars.allSatisfy({ scalar in
                  scalar.value >= 0x21 && scalar.value <= 0x7e
              }) else {
            throw AudioToMIDIValidationError.invalid("\(field) is empty, oversized, or contains unsafe characters.")
        }
    }

    private static func requireSHA256(_ value: String, field: String) throws {
        guard value.utf8.count == 64,
              value.unicodeScalars.allSatisfy({ scalar in
                  (0x30...0x39).contains(scalar.value) || (0x61...0x66).contains(scalar.value)
              }) else {
            throw AudioToMIDIValidationError.invalid("\(field) must be a lowercase SHA-256 digest.")
        }
    }

    private static func rejectUnknownKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        context: String
    ) throws {
        let unknown = Set(object.keys).subtracting(allowed)
        guard unknown.isEmpty else {
            throw AudioToMIDIValidationError.invalid(
                "The untrusted \(context) contains forbidden or unknown keys: \(unknown.sorted().joined(separator: ", "))."
            )
        }
    }

    private static func canonicalDouble(_ value: Double) -> String {
        String(format: "%.9f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func isOrderedAfter(
        _ lhs: (Double, Int, String),
        _ rhs: (Double, Int, String)
    ) -> Bool {
        if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
        if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
        return lhs.2 > rhs.2
    }
}

/// A deterministic test double. It does not analyze audio and is not a production transcription
/// claim. Its sole purpose is contract, replay, preservation, and stale-result testing.
public struct DeterministicMockAudioToMIDIProposer: Sendable {
    public static let algorithm = AudioToMIDIAlgorithmIdentity(
        implementationOwner: "TrackSmith",
        algorithmIdentifier: "tracksmith.fixture.audio-to-midi",
        algorithmVersion: "1"
    )

    public init() {}

    public func propose(for request: AudioToMIDIRequest) throws -> AudioToMIDIProposalSet {
        let validator = AudioToMIDIValidator(
            allowedAlgorithmIdentifiers: [Self.algorithm.algorithmIdentifier]
        )
        try validator.validate(request: request)
        guard request.algorithm == Self.algorithm else {
            throw AudioToMIDIValidationError.invalid("The deterministic mock received another algorithm identity.")
        }

        var generator = FixedLCG(state: request.replaySeed)
        let duration = request.format.durationSeconds
        let slotCount = max(1, min(8, Int(duration / 0.5)))
        let slotDuration = duration / Double(slotCount)
        let scale = [0, 2, 4, 7, 9]
        var notes: [MIDINoteProposal] = []
        notes.reserveCapacity(slotCount)
        for index in 0..<slotCount {
            let pitch = 60 + scale[Int(generator.next() % UInt64(scale.count))]
            let start = Double(index) * slotDuration
            let noteDuration = min(max(0.01, slotDuration * 0.72), duration - start)
            let velocity = 72 + Int(generator.next() % 25)
            let confidence = 0.70 + Double(generator.next() % 251) / 1_000
            notes.append(
                MIDINoteProposal(
                    proposalID: String(format: "fixture-note-%04d", index),
                    pitch: pitch,
                    startSeconds: start,
                    durationSeconds: noteDuration,
                    confidence: confidence,
                    velocity: velocity
                )
            )
        }

        let preservation = AudioToMIDISourcePreservation(
            originalAudioUnmodified: true,
            originalMIDIUnmodified: true,
            outputIsProposalOnly: true,
            destinationIsolatedFromSources: true,
            preservedAudioSHA256: request.sourceAudio.audioSHA256,
            preservedMIDISHA256: request.existingMIDI?.midiSHA256
        )
        let provenance = AudioToMIDIProvenance(
            requestID: request.requestID,
            requestFingerprint: AudioToMIDIValidator.requestFingerprint(request),
            sourceID: request.sourceAudio.sourceID,
            captureID: request.sourceAudio.captureID,
            sourceAudioSHA256: request.sourceAudio.audioSHA256,
            sourceRevision: request.sourceRevision,
            replaySeed: request.replaySeed,
            format: request.format,
            algorithm: request.algorithm,
            executionBoundary: request.executionBoundary,
            generatedLocally: true,
            networkAccessed: false,
            renderThreadUsed: false,
            syntheticFixture: true
        )
        let checksum = AudioToMIDIValidator.replayChecksum(
            notes: notes,
            preservation: preservation,
            provenance: provenance
        )
        let output = AudioToMIDIProposalSet(
            notes: notes,
            preservation: preservation,
            provenance: provenance,
            replayChecksum: checksum
        )
        try validator.validate(
            proposalSet: output,
            for: request,
            currentSourceRevision: request.sourceRevision
        )
        return output
    }
}

public enum AudioToMIDIDeterministicFixtures {
    public static func request() -> AudioToMIDIRequest {
        AudioToMIDIRequest(
            requestID: "fixture-request-v1",
            sourceRevision: 7,
            replaySeed: 0x5452_4143_4B53_4D49,
            sourceAudio: AudioSourceIdentity(
                sourceID: "fixture-vocal-source",
                captureID: "fixture-capture-001",
                audioSHA256: String(repeating: "a", count: 64)
            ),
            existingMIDI: ExistingMIDIIdentity(
                midiID: "fixture-existing-midi",
                midiSHA256: String(repeating: "b", count: 64)
            ),
            format: AudioFormatMetadata(sampleRate: 48_000, channelCount: 1, frameCount: 192_000),
            algorithm: DeterministicMockAudioToMIDIProposer.algorithm,
            executionBoundary: .offlineCLI
        )
    }

    /// Exercises deterministic replay plus strict round-trip validation without touching user audio.
    public static func selfCheck() throws -> Bool {
        let request = request()
        let proposer = DeterministicMockAudioToMIDIProposer()
        let first = try proposer.propose(for: request)
        let second = try proposer.propose(for: request)
        guard first == second else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encoded = try encoder.encode(first)
        let validator = AudioToMIDIValidator(
            allowedAlgorithmIdentifiers: [DeterministicMockAudioToMIDIProposer.algorithm.algorithmIdentifier]
        )
        let decoded = try validator.decodeAndValidateUntrusted(
            encoded,
            for: request,
            currentSourceRevision: request.sourceRevision
        )
        guard decoded == first else { return false }

        var staleWasRejected = false
        do {
            try validator.validate(
                proposalSet: first,
                for: request,
                currentSourceRevision: request.sourceRevision + 1
            )
        } catch is AudioToMIDIValidationError {
            staleWasRejected = true
        }

        var forbiddenKeyWasRejected = false
        if var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
            object["executableCode"] = "do-not-run"
            let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            do {
                _ = try validator.decodeAndValidateUntrusted(
                    tampered,
                    for: request,
                    currentSourceRevision: request.sourceRevision
                )
            } catch is AudioToMIDIValidationError {
                forbiddenKeyWasRejected = true
            }
        }
        return staleWasRejected && forbiddenKeyWasRejected
    }
}

private struct FixedLCG {
    private var state: UInt64

    init(state: UInt64) {
        self.state = state == 0 ? 0x9E37_79B9_7F4A_7C15 : state
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

private enum StableFNV1a {
    static func hex(_ string: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
