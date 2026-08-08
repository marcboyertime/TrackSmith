import CryptoKit
import Foundation
import PlanSchema

/// Everything TrackSmith remembers about this user's setup and confirmed
/// results. Every field is either explicitly entered or explicitly confirmed —
/// nothing here is inferred from a single session, and nothing here is ever
/// presented as general production truth.
public struct TutorPersonalProfile: Codable, Equatable, Sendable {
    public var version: String
    public var createdAt: Date
    public var updatedAt: Date

    // Explicitly entered setup.
    public var logicVersion: String?
    public var microphones: [String]
    public var interfaces: [String]
    public var roomNotes: String?
    public var availablePlugins: [String]
    public var genres: [String]
    public var referenceTracks: [String]
    public var preferredExplanationDepth: TutorExplanationDepth?
    public var preservationPreferences: [String]

    // Practice history.
    public var proceduresCompleted: [String]
    public var conceptsPracticed: [TutorConceptID]
    public var recurringProblems: [String]

    // Confirmed outcomes, kept separate from general knowledge.
    public var outcomes: [PersonalOutcomeRecord]

    public init(
        version: String = "1.0",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        logicVersion: String? = nil,
        microphones: [String] = [],
        interfaces: [String] = [],
        roomNotes: String? = nil,
        availablePlugins: [String] = [],
        genres: [String] = [],
        referenceTracks: [String] = [],
        preferredExplanationDepth: TutorExplanationDepth? = nil,
        preservationPreferences: [String] = [],
        proceduresCompleted: [String] = [],
        conceptsPracticed: [TutorConceptID] = [],
        recurringProblems: [String] = [],
        outcomes: [PersonalOutcomeRecord] = []
    ) {
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.logicVersion = logicVersion
        self.microphones = microphones
        self.interfaces = interfaces
        self.roomNotes = roomNotes
        self.availablePlugins = availablePlugins
        self.genres = genres
        self.referenceTracks = referenceTracks
        self.preferredExplanationDepth = preferredExplanationDepth
        self.preservationPreferences = preservationPreferences
        self.proceduresCompleted = proceduresCompleted
        self.conceptsPracticed = conceptsPracticed
        self.recurringProblems = recurringProblems
        self.outcomes = outcomes
    }

    public static let empty = TutorPersonalProfile()

    public var isEmpty: Bool {
        logicVersion == nil && microphones.isEmpty && interfaces.isEmpty
            && roomNotes == nil && availablePlugins.isEmpty && genres.isEmpty
            && referenceTracks.isEmpty && preservationPreferences.isEmpty
            && proceduresCompleted.isEmpty && conceptsPracticed.isEmpty
            && recurringProblems.isEmpty && outcomes.isEmpty
    }

    /// Outcomes the user asked to remember and reported as helping. These may
    /// influence ranking for this user; they never become general claims.
    public var confirmedHelpful: [PersonalOutcomeRecord] {
        outcomes.filter { $0.userAskedToRemember && $0.feedback == .better }
    }

    /// Outcomes the user asked to remember and reported as not helping.
    public var confirmedUnhelpful: [PersonalOutcomeRecord] {
        outcomes.filter { $0.userAskedToRemember && ($0.feedback == .worse || $0.feedback == .noChange) }
    }

    /// Strategy IDs this user confirmed helped, for retrieval preference.
    public var preferredStrategyIDs: Set<String> {
        Set(confirmedHelpful.compactMap(\.strategyID))
    }

    /// Strategy IDs this user confirmed did not help.
    public var deprioritizedStrategyIDs: Set<String> {
        Set(confirmedUnhelpful.compactMap(\.strategyID))
    }

    /// A human-readable export. Deliberately plain text so the user can read
    /// exactly what is stored about them.
    public func humanReadableSummary() -> String {
        var lines = ["TrackSmith personal production profile", ""]
        func section(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            lines.append(title)
            lines.append(contentsOf: items.map { "  - " + $0 })
            lines.append("")
        }
        if let logicVersion { section("Logic version", [logicVersion]) }
        section("Microphones", microphones)
        section("Interfaces", interfaces)
        if let roomNotes { section("Room notes (your words)", [roomNotes]) }
        section("Available plug-ins", availablePlugins)
        section("Genres", genres)
        section("Reference tracks", referenceTracks)
        section("Preservation preferences", preservationPreferences)
        section("Procedures completed", proceduresCompleted)
        section("Concepts practiced", conceptsPracticed.map(\.rawValue))
        section("Recurring problems", recurringProblems)
        if !outcomes.isEmpty {
            lines.append("Confirmed results (yours only — not general advice)")
            for outcome in outcomes {
                var parts = ["\(outcome.feedback.rawValue): \(outcome.question)"]
                if let improved = outcome.whatImproved { parts.append("improved: \(improved)") }
                if !outcome.userEnteredSettings.isEmpty {
                    parts.append("your settings: " + outcome.userEnteredSettings.joined(separator: ", "))
                }
                lines.append("  - " + parts.joined(separator: " | "))
            }
            lines.append("")
        }
        if isEmpty { lines.append("(nothing stored yet)") }
        lines.append("This profile is local only. It is never uploaded and never")
        lines.append("presented to you or anyone else as general production truth.")
        return lines.joined(separator: "\n")
    }
}

public enum PersonalProfileStoreError: Error, Equatable, Sendable {
    case unsafeRoot
    case profileTooLarge
    case unsupportedVersion(String)
    case corruptProfile
    case fileOperation(String)
}

/// Bounded, checksummed, atomic local storage for the personal profile.
/// Same discipline as the tutor session store, separate root and schema.
public struct PersonalProfileStore: @unchecked Sendable {
    public static let maximumFileBytes = 512 * 1_024
    public static let maximumOutcomes = 200
    public static let maximumListEntries = 60
    public static let maximumTextBytes = 2_048

    public var rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public init(fileManager: FileManager = .default) throws {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw PersonalProfileStoreError.fileOperation("Application Support is unavailable.")
        }
        self.init(
            rootURL: applicationSupport
                .appendingPathComponent("com.marcboyer.tracksmith", isDirectory: true)
                .appendingPathComponent("ProductionTutor", isDirectory: true),
            fileManager: fileManager
        )
    }

    public var profileURL: URL { rootURL.appendingPathComponent("personal-profile.json") }

    public func save(_ input: TutorPersonalProfile) throws {
        try prepareRoot()
        var profile = bounded(input)
        profile.version = "1.0"
        profile.updatedAt = Date()
        let body = try canonicalEncoder().encode(profile)
        guard body.count <= Self.maximumFileBytes / 2 else {
            throw PersonalProfileStoreError.profileTooLarge
        }
        let checksum = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let envelope = PersistedProfileEnvelope(
            envelopeVersion: "1.0", checksumSHA256: checksum, profile: profile
        )
        let encoder = canonicalEncoder()
        encoder.outputFormatting.insert(.prettyPrinted)
        let data = try encoder.encode(envelope)
        guard data.count <= Self.maximumFileBytes else {
            throw PersonalProfileStoreError.profileTooLarge
        }
        do {
            try data.write(to: profileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: profileURL.path)
        } catch {
            throw PersonalProfileStoreError.fileOperation("Profile could not be written atomically.")
        }
    }

    public func load() throws -> TutorPersonalProfile {
        try prepareRoot()
        guard fileManager.fileExists(atPath: profileURL.path) else { return .empty }
        do {
            let values = try profileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true,
                  (values.fileSize ?? Self.maximumFileBytes + 1) <= Self.maximumFileBytes else {
                try quarantine()
                throw PersonalProfileStoreError.corruptProfile
            }
            let data = try Data(contentsOf: profileURL, options: [.mappedIfSafe])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let envelope = try? decoder.decode(PersistedProfileEnvelope.self, from: data) else {
                try quarantine()
                throw PersonalProfileStoreError.corruptProfile
            }
            guard envelope.envelopeVersion == "1.0", envelope.profile.version == "1.0" else {
                throw PersonalProfileStoreError.unsupportedVersion(envelope.profile.version)
            }
            let canonical = try canonicalEncoder().encode(envelope.profile)
            let checksum = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
            guard checksum == envelope.checksumSHA256 else {
                try quarantine()
                throw PersonalProfileStoreError.corruptProfile
            }
            return envelope.profile
        } catch let error as PersonalProfileStoreError {
            throw error
        } catch {
            try? quarantine()
            throw PersonalProfileStoreError.corruptProfile
        }
    }

    /// Removes a single remembered outcome by ID.
    public func forget(outcomeID: UUID) throws {
        var profile = try load()
        profile.outcomes.removeAll { $0.id == outcomeID }
        try save(profile)
    }

    /// Deletes everything TrackSmith has learned about this user.
    public func deleteAll() throws {
        guard fileManager.fileExists(atPath: profileURL.path) else { return }
        do { try fileManager.removeItem(at: profileURL) }
        catch { throw PersonalProfileStoreError.fileOperation("Profile could not be deleted.") }
    }

    // MARK: - Internals

    private func prepareRoot() throws {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let values = try rootURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw PersonalProfileStoreError.unsafeRoot
            }
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        } catch let error as PersonalProfileStoreError {
            throw error
        } catch {
            throw PersonalProfileStoreError.fileOperation("Profile storage is unavailable.")
        }
    }

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func bounded(_ input: TutorPersonalProfile) -> TutorPersonalProfile {
        var profile = input
        func cap(_ items: [String]) -> [String] {
            Array(items.prefix(Self.maximumListEntries)).map(redact)
        }
        profile.microphones = cap(profile.microphones)
        profile.interfaces = cap(profile.interfaces)
        profile.availablePlugins = cap(profile.availablePlugins)
        profile.genres = cap(profile.genres)
        profile.referenceTracks = cap(profile.referenceTracks)
        profile.preservationPreferences = cap(profile.preservationPreferences)
        profile.proceduresCompleted = cap(profile.proceduresCompleted)
        profile.recurringProblems = cap(profile.recurringProblems)
        profile.roomNotes = profile.roomNotes.map(redact)
        profile.logicVersion = profile.logicVersion.map(redact)
        profile.outcomes = Array(profile.outcomes.suffix(Self.maximumOutcomes)).map { outcome in
            var outcome = outcome
            outcome.question = redact(outcome.question)
            outcome.contextSummary = redact(outcome.contextSummary)
            outcome.userEnteredSettings = cap(outcome.userEnteredSettings)
            outcome.whatImproved = outcome.whatImproved.map(redact)
            outcome.whatDidNot = outcome.whatDidNot.map(redact)
            outcome.whatWasPreserved = outcome.whatWasPreserved.map(redact)
            return outcome
        }
        return profile
    }

    private func redact(_ text: String) -> String {
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
                in: result, range: range, withTemplate: "[REDACTED CREDENTIAL]"
            )
        }
        while result.utf8.count > Self.maximumTextBytes, !result.isEmpty { result.removeLast() }
        return result
    }

    private func quarantine() throws {
        guard fileManager.fileExists(atPath: profileURL.path) else { return }
        let destination = rootURL.appendingPathComponent(
            "quarantine-profile-\(Date().timeIntervalSince1970).json"
        )
        do { try fileManager.moveItem(at: profileURL, to: destination) }
        catch { throw PersonalProfileStoreError.fileOperation("Corrupt profile could not be quarantined.") }
    }
}

private struct PersistedProfileEnvelope: Codable {
    var envelopeVersion: String
    var checksumSHA256: String
    var profile: TutorPersonalProfile
}
