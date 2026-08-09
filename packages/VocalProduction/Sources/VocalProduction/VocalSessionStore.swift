import CryptoKit
import Foundation

public enum VocalSessionAuthorityStatus: String, Codable, CaseIterable, Sendable {
    case current
    case staleSourceDemoted
    case sourceUnavailableReadOnly
}

public struct VocalPreviewAncestryRecord: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var candidateID: UUID
    public var parentPreviewID: UUID?
    public var parentAssetID: UUID?
    public var sourceSnapshotID: UUID
    public var createdAt: Date

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        candidateID: UUID,
        parentPreviewID: UUID? = nil,
        parentAssetID: UUID? = nil,
        sourceSnapshotID: UUID,
        createdAt: Date
    ) {
        self.version = version
        self.id = id
        self.candidateID = candidateID
        self.parentPreviewID = parentPreviewID
        self.parentAssetID = parentAssetID
        self.sourceSnapshotID = sourceSnapshotID
        self.createdAt = createdAt
    }
}

public struct VocalAssetAncestryRecord: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var candidateID: UUID
    public var parentPreviewID: UUID?
    public var parentAssetID: UUID?
    public var ancestorAssetIDs: [UUID]
    public var manifest: VocalRenderedAssetManifest

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        candidateID: UUID,
        parentPreviewID: UUID? = nil,
        parentAssetID: UUID? = nil,
        ancestorAssetIDs: [UUID] = [],
        manifest: VocalRenderedAssetManifest
    ) {
        self.version = version
        self.id = id
        self.candidateID = candidateID
        self.parentPreviewID = parentPreviewID
        self.parentAssetID = parentAssetID
        self.ancestorAssetIDs = ancestorAssetIDs
        self.manifest = manifest
    }
}

public struct VocalStoredHandoffRecord: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var handoff: VocalGuideCreateHandoff
    public var authorityStatus: VocalSessionAuthorityStatus
    public var executable: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        handoff: VocalGuideCreateHandoff,
        authorityStatus: VocalSessionAuthorityStatus = .current,
        executable: Bool = true
    ) {
        self.version = version
        self.id = id
        self.handoff = handoff
        self.authorityStatus = authorityStatus
        self.executable = executable
    }
}

public struct VocalConfirmedCreativePreference: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var candidateID: UUID
    public var preferredAspects: [VocalAspect]
    public var note: String?
    public var explicitlyConfirmedByUser: Bool
    public var confirmedAt: Date

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        candidateID: UUID,
        preferredAspects: [VocalAspect],
        note: String? = nil,
        explicitlyConfirmedByUser: Bool,
        confirmedAt: Date
    ) {
        self.version = version
        self.id = id
        self.candidateID = candidateID
        self.preferredAspects = preferredAspects
        self.note = note
        self.explicitlyConfirmedByUser = explicitlyConfirmedByUser
        self.confirmedAt = confirmedAt
    }
}

public struct VocalSessionState: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var authorityStatus: VocalSessionAuthorityStatus
    public var sourceAuthority: VocalSourceAuthority?
    public var captureBrief: VocalCaptureBrief?
    public var captureInterpretations: [VocalCaptureInterpretation]
    public var testTakeAssessments: [VocalTestTakeAssessment]
    public var captureRevisions: [VocalCaptureRevisionResult]
    public var confirmedCapturePreferences: [VocalConfirmedCapturePreference]
    public var creativeIntents: [VocalCreativeIntent]
    public var candidates: [VocalCreativeCandidate]
    public var revisions: [VocalRevisionRecord]
    public var previews: [VocalPreviewAncestryRecord]
    public var assets: [VocalAssetAncestryRecord]
    public var handoffs: [VocalStoredHandoffRecord]
    public var confirmedCreativePreferences: [VocalConfirmedCreativePreference]
    public var selectedCaptureInterpretationID: UUID?
    public var selectedCandidateID: UUID?

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        authorityStatus: VocalSessionAuthorityStatus = .current,
        sourceAuthority: VocalSourceAuthority? = nil,
        captureBrief: VocalCaptureBrief? = nil,
        captureInterpretations: [VocalCaptureInterpretation] = [],
        testTakeAssessments: [VocalTestTakeAssessment] = [],
        captureRevisions: [VocalCaptureRevisionResult] = [],
        confirmedCapturePreferences: [VocalConfirmedCapturePreference] = [],
        creativeIntents: [VocalCreativeIntent] = [],
        candidates: [VocalCreativeCandidate] = [],
        revisions: [VocalRevisionRecord] = [],
        previews: [VocalPreviewAncestryRecord] = [],
        assets: [VocalAssetAncestryRecord] = [],
        handoffs: [VocalStoredHandoffRecord] = [],
        confirmedCreativePreferences: [VocalConfirmedCreativePreference] = [],
        selectedCaptureInterpretationID: UUID? = nil,
        selectedCandidateID: UUID? = nil
    ) {
        self.version = version
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorityStatus = authorityStatus
        self.sourceAuthority = sourceAuthority
        self.captureBrief = captureBrief
        self.captureInterpretations = captureInterpretations
        self.testTakeAssessments = testTakeAssessments
        self.captureRevisions = captureRevisions
        self.confirmedCapturePreferences = confirmedCapturePreferences
        self.creativeIntents = creativeIntents
        self.candidates = candidates
        self.revisions = revisions
        self.previews = previews
        self.assets = assets
        self.handoffs = handoffs
        self.confirmedCreativePreferences = confirmedCreativePreferences
        self.selectedCaptureInterpretationID = selectedCaptureInterpretationID
        self.selectedCandidateID = selectedCandidateID
    }
}

public struct VocalSessionLoadResult: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var state: VocalSessionState
    public var staleAuthorityDemoted: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        state: VocalSessionState,
        staleAuthorityDemoted: Bool
    ) {
        self.version = version
        self.state = state
        self.staleAuthorityDemoted = staleAuthorityDemoted
    }
}

public enum VocalSessionStoreError: Error, Equatable, CustomStringConvertible, Sendable {
    case unsafeRoot
    case unsafeSubdirectoryName
    case missingSession(UUID)
    case stateTooLarge
    case unsupportedVersion(String)
    case invalidState(String)
    case corruptState
    case fileOperation(String)

    public var description: String {
        switch self {
        case .unsafeRoot: "TrackSmith Vocal session root is missing, symlinked, or not a directory."
        case .unsafeSubdirectoryName: "TrackSmith Vocal subdirectory must be one caller-chosen path component."
        case let .missingSession(id): "TrackSmith Vocal session \(id) does not exist."
        case .stateTooLarge: "TrackSmith Vocal session exceeds a bounded count, text, or file limit."
        case let .unsupportedVersion(version): "Unsupported TrackSmith Vocal session version: \(version)."
        case let .invalidState(reason): "Invalid TrackSmith Vocal session state: \(reason)"
        case .corruptState: "TrackSmith Vocal session failed decoding or checksum verification and was quarantined."
        case let .fileOperation(reason): "TrackSmith Vocal session file operation failed: \(reason)"
        }
    }
}

/// Atomic, checksummed persistence for TrackSmith Vocal state. The caller
/// chooses the local root or base/subdirectory; no Home or global product path
/// is hardcoded here. Stored state contains no credentials by design, and all
/// retained text passes a final credential redactor before checksumming.
public struct VocalSessionStore: @unchecked Sendable {
    public static let maximumFileBytes = 4 * 1_024 * 1_024
    public static let maximumTextBytes = 16_384
    public static let maximumCaptureInterpretations = 64
    public static let maximumAssessments = 128
    public static let maximumCaptureRevisions = 128
    public static let maximumConfirmedPreferences = 128
    public static let maximumCreativeIntents = 128
    public static let maximumCandidates = 256
    public static let maximumRevisions = 256
    public static let maximumPreviews = 256
    public static let maximumAssets = 128
    public static let maximumHandoffs = 64

    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public init(
        baseDirectoryURL: URL,
        subdirectoryName: String,
        fileManager: FileManager = .default
    ) throws {
        let trimmed = subdirectoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              !trimmed.contains("/"),
              !trimmed.contains(":"),
              URL(fileURLWithPath: trimmed).lastPathComponent == trimmed else {
            throw VocalSessionStoreError.unsafeSubdirectoryName
        }
        self.init(
            rootURL: baseDirectoryURL.appendingPathComponent(trimmed, isDirectory: true),
            fileManager: fileManager
        )
    }

    @discardableResult
    public func save(
        _ input: VocalSessionState,
        updatedAt: Date? = nil
    ) throws -> URL {
        try prepareRoot()
        var state = try redacted(input)
        try requireCompletedBindingCaptureRecords(input: input, redacted: state)
        state.version = .v1
        if let updatedAt { state.updatedAt = updatedAt }
        try validate(state)
        let canonical = try canonicalEncoder().encode(state)
        guard canonical.count <= Self.maximumFileBytes / 2 else {
            throw VocalSessionStoreError.stateTooLarge
        }
        let envelope = PersistedVocalSessionEnvelope(
            envelopeVersion: "1.0",
            checksumSHA256: digest(canonical),
            state: state
        )
        let encoder = canonicalEncoder()
        encoder.outputFormatting.insert(.prettyPrinted)
        let data: Data
        do { data = try encoder.encode(envelope) }
        catch { throw VocalSessionStoreError.invalidState("State is not encodable.") }
        guard data.count <= Self.maximumFileBytes else {
            throw VocalSessionStoreError.stateTooLarge
        }
        let destination = sessionURL(state.id)
        do {
            try data.write(to: destination, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch {
            throw VocalSessionStoreError.fileOperation("Session could not be written atomically.")
        }
        return destination
    }

    public func load(
        sessionID: UUID,
        currentSourceAuthority: VocalSourceAuthority? = nil,
        quarantineDate: Date = Date(),
        quarantineID: UUID = UUID()
    ) throws -> VocalSessionLoadResult {
        try prepareRoot()
        let url = sessionURL(sessionID)
        guard fileManager.fileExists(atPath: url.path) else {
            throw VocalSessionStoreError.missingSession(sessionID)
        }
        do {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            guard values.isSymbolicLink != true,
                  values.isRegularFile == true,
                  (values.fileSize ?? Self.maximumFileBytes + 1) <= Self.maximumFileBytes else {
                try quarantine(url, date: quarantineDate, quarantineID: quarantineID)
                throw VocalSessionStoreError.corruptState
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let decoder = canonicalDecoder()
            guard let envelope = try? decoder.decode(PersistedVocalSessionEnvelope.self, from: data) else {
                try quarantine(url, date: quarantineDate, quarantineID: quarantineID)
                throw VocalSessionStoreError.corruptState
            }
            guard envelope.envelopeVersion == "1.0" else {
                throw VocalSessionStoreError.unsupportedVersion(envelope.envelopeVersion)
            }
            guard envelope.state.version == .v1 else {
                throw VocalSessionStoreError.unsupportedVersion(envelope.state.version.rawValue)
            }
            let canonical = try canonicalEncoder().encode(envelope.state)
            guard digest(canonical) == envelope.checksumSHA256,
                  envelope.state.id == sessionID else {
                try quarantine(url, date: quarantineDate, quarantineID: quarantineID)
                throw VocalSessionStoreError.corruptState
            }
            try validate(envelope.state)
            let demoted = demoteIfStale(envelope.state, current: currentSourceAuthority)
            return VocalSessionLoadResult(
                state: demoted.state,
                staleAuthorityDemoted: demoted.didDemote
            )
        } catch let error as VocalSessionStoreError {
            throw error
        } catch {
            try? quarantine(url, date: quarantineDate, quarantineID: quarantineID)
            throw VocalSessionStoreError.corruptState
        }
    }

    public func delete(sessionID: UUID) throws {
        try prepareRoot()
        let url = sessionURL(sessionID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw VocalSessionStoreError.fileOperation("Refusing to delete a non-regular or symlinked session file.")
            }
            try fileManager.removeItem(at: url)
        } catch let error as VocalSessionStoreError {
            throw error
        } catch {
            throw VocalSessionStoreError.fileOperation("Session could not be deleted.")
        }
    }

    public func sessionURL(_ sessionID: UUID) -> URL {
        rootURL.appendingPathComponent(
            "tracksmith-vocal-session-\(sessionID.uuidString.lowercased()).json",
            isDirectory: false
        )
    }

    public func quarantineURL(date: Date, quarantineID: UUID) -> URL {
        let milliseconds = Int64((date.timeIntervalSince1970 * 1_000).rounded(.down))
        return rootURL.appendingPathComponent(
            "quarantine-tracksmith-vocal-\(milliseconds)-\(quarantineID.uuidString.lowercased()).json",
            isDirectory: false
        )
    }

    private func prepareRoot() throws {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let values = try rootURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw VocalSessionStoreError.unsafeRoot
            }
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        } catch let error as VocalSessionStoreError {
            throw error
        } catch {
            throw VocalSessionStoreError.fileOperation("Session root is unavailable.")
        }
    }

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private func canonicalDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func validate(_ state: VocalSessionState) throws {
        guard state.captureInterpretations.count <= Self.maximumCaptureInterpretations,
              state.testTakeAssessments.count <= Self.maximumAssessments,
              state.captureRevisions.count <= Self.maximumCaptureRevisions,
              state.confirmedCapturePreferences.count <= Self.maximumConfirmedPreferences,
              state.creativeIntents.count <= Self.maximumCreativeIntents,
              state.candidates.count <= Self.maximumCandidates,
              state.revisions.count <= Self.maximumRevisions,
              state.previews.count <= Self.maximumPreviews,
              state.assets.count <= Self.maximumAssets,
              state.handoffs.count <= Self.maximumHandoffs,
              state.confirmedCreativePreferences.count <= Self.maximumConfirmedPreferences else {
            throw VocalSessionStoreError.stateTooLarge
        }
        try requireUnique(state.captureInterpretations.map(\.id), label: "capture interpretation")
        try requireUnique(state.testTakeAssessments.map(\.id), label: "assessment")
        try requireUnique(state.confirmedCapturePreferences.map(\.id), label: "capture preference")
        try requireUnique(state.creativeIntents.map(\.id), label: "creative intent")
        try requireUnique(state.candidates.map(\.id), label: "candidate")
        try requireUnique(state.revisions.map(\.id), label: "revision")
        try requireUnique(state.previews.map(\.id), label: "preview")
        try requireUnique(state.assets.map(\.id), label: "asset")
        try requireUnique(state.handoffs.map(\.id), label: "handoff")
        try requireUnique(state.confirmedCreativePreferences.map(\.id), label: "creative preference")

        let captureIDs = Set(state.captureInterpretations.map(\.id))
        if let selected = state.selectedCaptureInterpretationID, !captureIDs.contains(selected) {
            throw VocalSessionStoreError.invalidState("Selected capture interpretation is absent.")
        }
        for revision in state.captureRevisions {
            guard let parent = revision.revisedInterpretation.parentInterpretationID,
                  captureIDs.contains(parent) || state.captureRevisions.contains(where: { $0.revisedInterpretation.id == parent }) else {
                throw VocalSessionStoreError.invalidState("Capture revision ancestry is incomplete.")
            }
        }

        let candidateIDs = Set(state.candidates.map(\.id))
        if let selected = state.selectedCandidateID, !candidateIDs.contains(selected) {
            throw VocalSessionStoreError.invalidState("Selected creative candidate is absent.")
        }
        for candidate in state.candidates {
            do { try VocalContractValidator().validate(candidate: candidate) }
            catch {
                throw VocalSessionStoreError.invalidState(
                    "Candidate \(candidate.id) failed local validation: \(error)"
                )
            }
            if let parent = candidate.parentCandidateID, !candidateIDs.contains(parent) {
                throw VocalSessionStoreError.invalidState("Candidate ancestry is incomplete.")
            }
            if let revisionID = candidate.revisionID,
               !state.revisions.contains(where: { $0.id == revisionID }) {
                throw VocalSessionStoreError.invalidState("Candidate references a missing revision.")
            }
            if let reverted = candidate.revertedToCandidateID, !candidateIDs.contains(reverted) {
                throw VocalSessionStoreError.invalidState("Exact-revert ancestry is incomplete.")
            }
            if let source = state.sourceAuthority,
               candidate.intent.sourceSnapshotID != source.sourceSnapshotID {
                throw VocalSessionStoreError.invalidState("Candidate targets a different stored source.")
            }
        }
        for revision in state.revisions {
            guard candidateIDs.contains(revision.baseCandidateID),
                  candidateIDs.contains(revision.resultCandidateID),
                  revision.exactAncestorCandidateIDs.allSatisfy({ candidateIDs.contains($0) }) else {
                throw VocalSessionStoreError.invalidState("Revision candidate ancestry is incomplete.")
            }
        }
        for preview in state.previews where !candidateIDs.contains(preview.candidateID) {
            throw VocalSessionStoreError.invalidState("Preview references a missing candidate.")
        }
        for asset in state.assets {
            guard candidateIDs.contains(asset.candidateID),
                  asset.id == asset.manifest.renderID,
                  asset.candidateID == asset.manifest.exactCandidateID,
                  asset.parentPreviewID == asset.manifest.parentPreviewID,
                  asset.parentAssetID == asset.manifest.parentAssetID,
                  asset.ancestorAssetIDs == asset.manifest.assetAncestry,
                  !asset.ancestorAssetIDs.contains(asset.id),
                  isSHA256(asset.manifest.renderHashSHA256) else {
                throw VocalSessionStoreError.invalidState("Asset ancestry or render identity is inconsistent.")
            }
            guard let sourceAuthority = state.sourceAuthority,
                  asset.manifest.sourceAuthority == sourceAuthority else {
                throw VocalSessionStoreError.invalidState(
                    "Persisted Vocal asset must retain the exact state source authority."
                )
            }
        }
        if let source = state.sourceAuthority, !isSHA256(source.contentHashSHA256) {
            throw VocalSessionStoreError.invalidState("Source content hash is not a lowercase SHA-256 digest.")
        }
        for preference in state.confirmedCreativePreferences {
            guard preference.explicitlyConfirmedByUser else {
                throw VocalSessionStoreError.invalidState("Unconfirmed creative preference cannot be persisted.")
            }
            guard candidateIDs.contains(preference.candidateID) else {
                throw VocalSessionStoreError.invalidState("Creative preference references a missing candidate.")
            }
        }
        for preference in state.confirmedCapturePreferences where !preference.feedback.explicitlyConfirmAsPreference {
            throw VocalSessionStoreError.invalidState("Unconfirmed capture preference cannot be persisted.")
        }
        for handoff in state.handoffs {
            guard handoff.id == handoff.handoff.id else {
                throw VocalSessionStoreError.invalidState("Stored handoff identity mismatch.")
            }
            if handoff.executable {
                guard let sourceAuthority = state.sourceAuthority,
                      handoff.handoff.captureAuthority.sourceAuthority == sourceAuthority else {
                    throw VocalSessionStoreError.invalidState(
                        "Executable Vocal handoff must retain the exact state source authority."
                    )
                }
                do { try VocalGuideCreateHandoffBuilder().validate(handoff.handoff) }
                catch { throw VocalSessionStoreError.invalidState("Executable handoff failed local validation.") }
            }
        }
    }

    private func requireUnique(_ values: [UUID], label: String) throws {
        guard Set(values).count == values.count else {
            throw VocalSessionStoreError.invalidState("Duplicate \(label) identity.")
        }
    }

    private func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }

    private func demoteIfStale(
        _ input: VocalSessionState,
        current: VocalSourceAuthority?
    ) -> (state: VocalSessionState, didDemote: Bool) {
        guard let current else { return (input, false) }
        guard let stored = input.sourceAuthority else {
            var copy = input
            copy.authorityStatus = .sourceUnavailableReadOnly
            copy.candidates = copy.candidates.map { candidate in
                var candidate = candidate
                candidate.authorityStatus = .staleSourceReadOnly
                candidate.realtimeActivatable = false
                return candidate
            }
            copy.handoffs = copy.handoffs.map { handoff in
                var handoff = handoff
                handoff.authorityStatus = .sourceUnavailableReadOnly
                handoff.executable = false
                return handoff
            }
            return (copy, true)
        }
        let matches = stored == current
        guard !matches else { return (input, false) }
        var copy = input
        copy.authorityStatus = .staleSourceDemoted
        copy.candidates = copy.candidates.map { candidate in
            var candidate = candidate
            candidate.authorityStatus = .staleSourceReadOnly
            candidate.realtimeActivatable = false
            return candidate
        }
        copy.handoffs = copy.handoffs.map { handoff in
            var handoff = handoff
            handoff.authorityStatus = .staleSourceDemoted
            handoff.executable = false
            return handoff
        }
        return (copy, true)
    }

    private func redacted(_ state: VocalSessionState) throws -> VocalSessionState {
        let encoded: Data
        do { encoded = try canonicalEncoder().encode(state) }
        catch { throw VocalSessionStoreError.invalidState("State is not encodable before redaction.") }
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: encoded) }
        catch { throw VocalSessionStoreError.invalidState("State cannot be inspected for credentials.") }
        let sanitized = redactJSON(object, key: nil)
        let data: Data
        do { data = try JSONSerialization.data(withJSONObject: sanitized, options: [.sortedKeys]) }
        catch { throw VocalSessionStoreError.invalidState("Redacted state is not valid JSON.") }
        do { return try canonicalDecoder().decode(VocalSessionState.self, from: data) }
        catch { throw VocalSessionStoreError.invalidState("Redaction produced invalid typed state.") }
    }

    /// A completed test-take embeds its binding identity in the immutable
    /// source ID. Its capture brief, interpretations, revisions, and
    /// assessments are recoverability-critical evidence, so save must refuse
    /// to silently redact or byte-truncate any of them. Creative preferences
    /// intentionally remain redactable personal text.
    private func requireCompletedBindingCaptureRecords(
        input: VocalSessionState,
        redacted: VocalSessionState
    ) throws {
        guard input.sourceAuthority.map(hasCompletedTestTakeBinding) ?? false else { return }
        guard input.captureBrief == redacted.captureBrief,
              input.captureInterpretations == redacted.captureInterpretations,
              input.captureRevisions == redacted.captureRevisions,
              input.testTakeAssessments == redacted.testTakeAssessments else {
            throw VocalSessionStoreError.invalidState(
                "Completed test-take binding records cannot be redacted or truncated during save."
            )
        }
    }

    private func hasCompletedTestTakeBinding(_ authority: VocalSourceAuthority) -> Bool {
        authority.immutableSourceID
            // Production durable identifiers are semicolon-delimited. Accept
            // newlines as well so older fixtures/snapshots remain fail-closed.
            .split(whereSeparator: { $0 == ";" || $0.isNewline })
            .contains { $0.hasPrefix("test-take-completion-sha256:") }
    }

    private func redactJSON(_ value: Any, key: String?) -> Any {
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            result.reserveCapacity(dictionary.count)
            for (childKey, child) in dictionary {
                result[childKey] = redactJSON(child, key: childKey)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { redactJSON($0, key: key) }
        }
        if let string = value as? String {
            return redactSecrets(string, key: key)
        }
        return value
    }

    private func redactSecrets(_ text: String, key: String?) -> String {
        let lowerKey = key?.lowercased() ?? ""
        if ["credential", "secret", "password", "authorization", "apikey", "api_key", "token"].contains(where: { lowerKey.contains($0) }) {
            return "[REDACTED CREDENTIAL]"
        }
        var result = text
        let patterns = [
            #"sk-[A-Za-z0-9_-]{8,}"#,
            #"AIza[A-Za-z0-9_-]{16,}"#,
            #"(?i)(api[_ -]?key|authorization|bearer|password|credential|secret)\s*[:=]?\s*[A-Za-z0-9._/+\-=]{8,}"#,
            #"(?i)bearer\s+[A-Za-z0-9._~+/=-]{8,}"#,
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "[REDACTED CREDENTIAL]"
            )
        }
        if result.utf8.count > Self.maximumTextBytes {
            var byteCount = 0
            var end = result.startIndex
            while end < result.endIndex {
                let next = result.index(after: end)
                let characterBytes = result[end..<next].utf8.count
                guard byteCount + characterBytes <= Self.maximumTextBytes else { break }
                byteCount += characterBytes
                end = next
            }
            result = String(result[..<end])
        }
        return result
    }

    private func quarantine(_ url: URL, date: Date, quarantineID: UUID) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let destination = quarantineURL(date: date, quarantineID: quarantineID)
        do { try fileManager.moveItem(at: url, to: destination) }
        catch { throw VocalSessionStoreError.fileOperation("Corrupt session could not be quarantined.") }
    }
}

private struct PersistedVocalSessionEnvelope: Codable {
    var envelopeVersion: String
    var checksumSHA256: String
    var state: VocalSessionState
}
