import CryptoKit
import Foundation

public enum TutorSessionStoreError: Error, Equatable, Sendable {
    case unsafeRoot
    case stateTooLarge
    case unsupportedVersion(String)
    case corruptState
    case fileOperation(String)
}

public struct TutorSessionRecord: Codable, Equatable, Sendable {
    public var version: String
    public var sessionID: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var lesson: TutorLessonState
    /// Bounded provider audit strings when a provider proposal was accepted.
    /// Raw provider responses are never persisted.
    public var providerAuditSummary: String?

    public init(
        version: String = "1.0",
        sessionID: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lesson: TutorLessonState,
        providerAuditSummary: String? = nil
    ) {
        self.version = version
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lesson = lesson
        self.providerAuditSummary = providerAuditSummary
    }
}

public struct TutorSessionLoadResult: Sendable {
    public var record: TutorSessionRecord
    public var migratedFromVersion: String?

    public init(record: TutorSessionRecord, migratedFromVersion: String? = nil) {
        self.record = record
        self.migratedFromVersion = migratedFromVersion
    }
}

/// Bounded, checksummed, atomic tutor persistence. Deliberately separate from
/// the frozen Production Intelligence conversation store: same discipline,
/// different root and schema.
public struct TutorSessionStore: @unchecked Sendable {
    public static let maximumFileBytes = 1_024 * 1_024
    public static let maximumFeedbackEvents = 200
    public static let maximumSteps = 64
    public static let maximumLimitations = 40
    public static let maximumTextBytes = 8_192

    public var rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public init(fileManager: FileManager = .default) throws {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw TutorSessionStoreError.fileOperation("Application Support is unavailable.")
        }
        self.init(
            rootURL: applicationSupport
                .appendingPathComponent("com.marcboyer.tracksmith", isDirectory: true)
                .appendingPathComponent("ProductionTutor", isDirectory: true),
            fileManager: fileManager
        )
    }

    public func save(_ unbounded: TutorSessionRecord) throws -> URL {
        try prepareRoot()
        var record = bounded(unbounded)
        record.version = "1.0"
        record.updatedAt = Date()
        let stateData = try canonicalEncoder().encode(record)
        guard stateData.count <= Self.maximumFileBytes / 2 else {
            throw TutorSessionStoreError.stateTooLarge
        }
        let checksum = SHA256.hash(data: stateData).map { String(format: "%02x", $0) }.joined()
        let envelope = PersistedTutorEnvelope(
            envelopeVersion: "1.0",
            checksumSHA256: checksum,
            record: record
        )
        let encoder = canonicalEncoder()
        encoder.outputFormatting.insert(.prettyPrinted)
        let data = try encoder.encode(envelope)
        guard data.count <= Self.maximumFileBytes else {
            throw TutorSessionStoreError.stateTooLarge
        }
        let destination = sessionURL(record.sessionID)
        do {
            try data.write(to: destination, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: destination.path
            )
        } catch {
            throw TutorSessionStoreError.fileOperation("Tutor session could not be written atomically.")
        }
        return destination
    }

    public func load(sessionID: UUID) throws -> TutorSessionLoadResult {
        try prepareRoot()
        let url = sessionURL(sessionID)
        do {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true,
                  (values.fileSize ?? Self.maximumFileBytes + 1) <= Self.maximumFileBytes else {
                try quarantine(url)
                throw TutorSessionStoreError.corruptState
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let envelope = try? decoder.decode(PersistedTutorEnvelope.self, from: data) else {
                try quarantine(url)
                throw TutorSessionStoreError.corruptState
            }
            guard envelope.envelopeVersion == "1.0", envelope.record.version == "1.0" else {
                throw TutorSessionStoreError.unsupportedVersion(envelope.record.version)
            }
            let canonical = try canonicalEncoder().encode(envelope.record)
            let checksum = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
            guard checksum == envelope.checksumSHA256,
                  envelope.record.sessionID == sessionID else {
                try quarantine(url)
                throw TutorSessionStoreError.corruptState
            }
            return TutorSessionLoadResult(record: envelope.record)
        } catch let error as TutorSessionStoreError {
            throw error
        } catch {
            try? quarantine(url)
            throw TutorSessionStoreError.corruptState
        }
    }

    public func sessionURL(_ sessionID: UUID) -> URL {
        rootURL.appendingPathComponent("tutor-session-\(sessionID.uuidString.lowercased()).json")
    }

    // MARK: - Internals

    private func prepareRoot() throws {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let values = try rootURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw TutorSessionStoreError.unsafeRoot
            }
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        } catch let error as TutorSessionStoreError {
            throw error
        } catch {
            throw TutorSessionStoreError.fileOperation("Tutor session storage is unavailable.")
        }
    }

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func bounded(_ input: TutorSessionRecord) -> TutorSessionRecord {
        var record = input
        record.lesson.requestText = redactSecrets(record.lesson.requestText)
        record.lesson.statusNote = redactSecrets(record.lesson.statusNote)
        record.lesson.clarificationQuestion = record.lesson.clarificationQuestion.map(redactSecrets)
        record.lesson.feedbackEvents = Array(
            record.lesson.feedbackEvents.suffix(Self.maximumFeedbackEvents)
        )
        record.lesson.steps = Array(record.lesson.steps.prefix(Self.maximumSteps))
        record.lesson.unresolvedLimitations = Array(
            record.lesson.unresolvedLimitations.prefix(Self.maximumLimitations)
        )
        record.providerAuditSummary = record.providerAuditSummary.map(redactSecrets)
        return record
    }

    private func redactSecrets(_ text: String) -> String {
        var result = text
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
        while result.utf8.count > Self.maximumTextBytes, !result.isEmpty { result.removeLast() }
        return result
    }

    private func quarantine(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let quarantine = rootURL.appendingPathComponent(
            "quarantine-\(Date().timeIntervalSince1970)-\(UUID().uuidString.lowercased()).json"
        )
        do { try fileManager.moveItem(at: url, to: quarantine) }
        catch { throw TutorSessionStoreError.fileOperation("Corrupt tutor state could not be quarantined.") }
    }
}

private struct PersistedTutorEnvelope: Codable {
    var envelopeVersion: String
    var checksumSHA256: String
    var record: TutorSessionRecord
}
