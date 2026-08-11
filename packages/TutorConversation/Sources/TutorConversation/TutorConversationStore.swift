import CryptoKit
import Darwin
import Foundation

public enum TutorConversationStoreError: Error, Equatable, Sendable {
    case unsafeRoot
    case stateTooLarge
    case receiptAlreadyExists
    case corruptState
    case unsupportedVersion(String)
    case fileOperation(String)
}

/// Bounded local persistence for Tutor conversation/experiment state plus an
/// append-only receipt directory. Conversation snapshots are mutable because
/// the user can continue or delete them; evidence receipts are write-once.
public struct TutorConversationStore: @unchecked Sendable {
    public static let maximumStateBytes = 2 * 1_024 * 1_024
    public static let maximumReceiptBytes = 512 * 1_024
    public static let maximumMessages = 240
    public static let maximumExperiments = 120
    public static let maximumTextBytes = 24 * 1_024

    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public init(fileManager: FileManager = .default) throws {
        guard let support = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw TutorConversationStoreError.fileOperation("Application Support is unavailable.")
        }
        self.init(
            rootURL: support
                .appendingPathComponent("com.marcboyer.tracksmith", isDirectory: true)
                .appendingPathComponent("TutorConversation", isDirectory: true),
            fileManager: fileManager
        )
    }

    public var conversationsURL: URL { rootURL.appendingPathComponent("conversations", isDirectory: true) }
    public var receiptsURL: URL { rootURL.appendingPathComponent("receipts", isDirectory: true) }

    public func save(_ input: TutorConversationState) throws {
        try prepareRoot()
        let state = try normalized(input)
        let encoder = canonicalEncoder()
        let body = try encoder.encode(state)
        guard body.count <= Self.maximumStateBytes / 2 else {
            throw TutorConversationStoreError.stateTooLarge
        }
        let envelope = TutorStateEnvelope(
            envelopeVersion: "1.0",
            checksumSHA256: sha256(body),
            state: state
        )
        let outputEncoder = canonicalEncoder(pretty: true)
        let data = try outputEncoder.encode(envelope)
        guard data.count <= Self.maximumStateBytes else {
            throw TutorConversationStoreError.stateTooLarge
        }
        do {
            try data.write(to: stateURL(state.id), options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL(state.id).path)
        } catch {
            throw TutorConversationStoreError.fileOperation("Tutor conversation could not be saved atomically.")
        }
    }

    public func load(conversationID: UUID) throws -> TutorConversationState {
        try prepareRoot()
        let url = stateURL(conversationID)
        guard fileManager.fileExists(atPath: url.path) else {
            return TutorConversationState(id: conversationID)
        }
        do {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true,
                  (values.fileSize ?? Self.maximumStateBytes + 1) <= Self.maximumStateBytes else {
                throw TutorConversationStoreError.corruptState
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(TutorStateEnvelope.self, from: data)
            guard envelope.envelopeVersion == "1.0", envelope.state.version == "1.0" else {
                throw TutorConversationStoreError.unsupportedVersion(envelope.state.version)
            }
            let body = try canonicalEncoder().encode(envelope.state)
            guard sha256(body) == envelope.checksumSHA256 else {
                throw TutorConversationStoreError.corruptState
            }
            return try normalized(envelope.state)
        } catch let error as TutorConversationStoreError {
            throw error
        } catch {
            throw TutorConversationStoreError.corruptState
        }
    }

    public func loadMostRecent() throws -> TutorConversationState? {
        try prepareRoot()
        let candidates = try fileManager.contentsOfDirectory(
            at: conversationsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        let ordered = try candidates.sorted {
            let lhs = try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhs = try $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhs > rhs
        }
        for url in ordered {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            if let state = try? load(conversationID: id) { return state }
        }
        return nil
    }

    /// Writes a new evidence receipt without any overwrite path. A duplicate
    /// ID is rejected even when the bytes match, making accidental mutation or
    /// replay visible to callers and tests.
    public func saveReceipt(_ receipt: TutorEvidenceReceipt) throws {
        try prepareRoot()
        let encoder = canonicalEncoder()
        let body = try encoder.encode(receipt)
        let envelope = TutorReceiptEnvelope(
            envelopeVersion: "1.0",
            checksumSHA256: sha256(body),
            receipt: receipt
        )
        let data = try canonicalEncoder(pretty: true).encode(envelope)
        guard data.count <= Self.maximumReceiptBytes else {
            throw TutorConversationStoreError.stateTooLarge
        }
        let url = receiptURL(receipt.id)
        let descriptor = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            if errno == EEXIST { throw TutorConversationStoreError.receiptAlreadyExists }
            throw TutorConversationStoreError.fileOperation("Evidence receipt could not be created exclusively.")
        }
        var completed = false
        defer {
            Darwin.close(descriptor)
            if !completed { Darwin.unlink(url.path) }
        }
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(descriptor, base.advanced(by: offset), rawBuffer.count - offset)
                guard written > 0 else {
                    throw TutorConversationStoreError.fileOperation("Evidence receipt could not be written completely.")
                }
                offset += written
            }
        }
        guard Darwin.fsync(descriptor) == 0 else {
            throw TutorConversationStoreError.fileOperation("Evidence receipt could not be synchronized.")
        }
        completed = true
    }

    public func loadReceipt(_ id: UUID) throws -> TutorEvidenceReceipt {
        try prepareRoot()
        let url = receiptURL(id)
        do {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true,
                  (values.fileSize ?? Self.maximumReceiptBytes + 1) <= Self.maximumReceiptBytes else {
                throw TutorConversationStoreError.corruptState
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(TutorReceiptEnvelope.self, from: data)
            let body = try canonicalEncoder().encode(envelope.receipt)
            guard envelope.envelopeVersion == "1.0",
                  envelope.receipt.version == "1.0",
                  sha256(body) == envelope.checksumSHA256 else {
                throw TutorConversationStoreError.corruptState
            }
            return envelope.receipt
        } catch let error as TutorConversationStoreError {
            throw error
        } catch {
            throw TutorConversationStoreError.corruptState
        }
    }

    public func deleteAll() throws {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        do { try fileManager.removeItem(at: rootURL) }
        catch { throw TutorConversationStoreError.fileOperation("Tutor history could not be deleted.") }
    }

    private func stateURL(_ id: UUID) -> URL {
        conversationsURL.appendingPathComponent(id.uuidString.lowercased()).appendingPathExtension("json")
    }

    private func receiptURL(_ id: UUID) -> URL {
        receiptsURL.appendingPathComponent(id.uuidString.lowercased()).appendingPathExtension("json")
    }

    private func prepareRoot() throws {
        do {
            for url in [rootURL, conversationsURL, receiptsURL] {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                guard values.isSymbolicLink != true, values.isDirectory == true else {
                    throw TutorConversationStoreError.unsafeRoot
                }
                try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            }
        } catch let error as TutorConversationStoreError {
            throw error
        } catch {
            throw TutorConversationStoreError.fileOperation("Tutor storage is unavailable.")
        }
    }

    /// Returns the exact redacted, size-bounded state that `save` persists.
    /// Engines use this before constructing evidence hashes so the visible
    /// transcript, receipt, and on-disk snapshot all refer to the same text.
    public func normalized(_ input: TutorConversationState) throws -> TutorConversationState {
        var state = input
        state.version = "1.0"
        state.projectGoal = state.projectGoal.map { redactAndBound($0) }
        state.messages = Array(state.messages.suffix(Self.maximumMessages)).map { message in
            var copy = message
            copy.text = redactAndBound(copy.text)
            copy.evidence = Array(copy.evidence.prefix(24)).map { evidence in
                var evidence = evidence
                evidence.label = redactAndBound(evidence.label, limit: 2_048)
                evidence.detail = redactAndBound(evidence.detail, limit: 4_096)
                return evidence
            }
            return copy
        }
        state.experiments = Array(state.experiments.suffix(Self.maximumExperiments)).map { experiment in
            var experiment = experiment
            experiment.draft.title = redactAndBound(experiment.draft.title, limit: 2_048)
            experiment.draft.logicLocation = redactAndBound(experiment.draft.logicLocation, limit: 4_096)
            experiment.draft.action = redactAndBound(experiment.draft.action, limit: 4_096)
            experiment.draft.startingRange = redactAndBound(experiment.draft.startingRange, limit: 2_048)
            experiment.draft.listenFor = redactAndBound(experiment.draft.listenFor, limit: 4_096)
            experiment.draft.why = redactAndBound(experiment.draft.why, limit: 4_096)
            experiment.draft.risk = redactAndBound(experiment.draft.risk, limit: 4_096)
            experiment.draft.undo = redactAndBound(experiment.draft.undo, limit: 4_096)
            experiment.draft.visualTargetQuery = experiment.draft.visualTargetQuery.map {
                redactAndBound($0, limit: 1_024)
            }
            experiment.userNote = experiment.userNote.map { redactAndBound($0, limit: 4_096) }
            experiment.userReportedSettings = Array(experiment.userReportedSettings.prefix(12)).map {
                redactAndBound($0, limit: 1_024)
            }
            return experiment
        }
        while try canonicalEncoder().encode(state).count > Self.maximumStateBytes / 2 {
            if state.messages.count > 1,
               state.experiments.count <= 1
                || state.messages[0].createdAt <= state.experiments[0].createdAt {
                state.messages.removeFirst()
            } else if state.experiments.count > 1 {
                state.experiments.removeFirst()
            } else {
                throw TutorConversationStoreError.stateTooLarge
            }
        }
        return state
    }

    private func redactAndBound(_ value: String, limit: Int = Self.maximumTextBytes) -> String {
        var result = value
        let patterns = [
            #"sk-[A-Za-z0-9_-]{8,}"#,
            #"AIza[A-Za-z0-9_-]{16,}"#,
            #"(?i)(api[_ -]?key|authorization|bearer)\s*[:=]?\s*[A-Za-z0-9._-]{8,}"#,
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
        while result.utf8.count > limit, !result.isEmpty { result.removeLast() }
        return result
    }

    private func canonicalEncoder(pretty: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
        return encoder
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct TutorStateEnvelope: Codable {
    var envelopeVersion: String
    var checksumSHA256: String
    var state: TutorConversationState
}

private struct TutorReceiptEnvelope: Codable {
    var envelopeVersion: String
    var checksumSHA256: String
    var receipt: TutorEvidenceReceipt
}
