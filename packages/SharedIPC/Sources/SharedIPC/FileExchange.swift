import CryptoKit
import Darwin
import Foundation

public struct ExchangeRejection: Equatable, Sendable {
    public var fileName: String
    public var reason: String
}

public struct ExchangeScan: Sendable {
    public var messages: [ExchangeMessage]
    public var rejections: [ExchangeRejection]
}

public struct InstanceScan: Sendable {
    public var instances: [PluginInstanceRecord]
    public var rejections: [ExchangeRejection]
}

public struct CachePurgeResult: Equatable, Sendable {
    public var removedArtifactEntries: Int
    public var removedPreviewEntries: Int

    public init(removedArtifactEntries: Int, removedPreviewEntries: Int) {
        self.removedArtifactEntries = removedArtifactEntries
        self.removedPreviewEntries = removedPreviewEntries
    }
}

public struct MailboxPolicy: Equatable, Sendable {
    public var maximumMessageFiles: Int
    public var maximumAggregateMessageBytes: Int
    public var maximumInstanceFiles: Int
    public var completedTransactionRetention: TimeInterval
    public var diagnosticRetention: TimeInterval
    public var staleInstanceRetention: TimeInterval
    public var maximumLiveCommandFileAge: TimeInterval

    public init(
        maximumMessageFiles: Int = 2_048,
        maximumAggregateMessageBytes: Int = 32 * 1_048_576,
        maximumInstanceFiles: Int = 512,
        completedTransactionRetention: TimeInterval = 10 * 60,
        diagnosticRetention: TimeInterval = 24 * 60 * 60,
        staleInstanceRetention: TimeInterval = 10 * 60,
        maximumLiveCommandFileAge: TimeInterval = 5 * 60
    ) {
        self.maximumMessageFiles = maximumMessageFiles
        self.maximumAggregateMessageBytes = maximumAggregateMessageBytes
        self.maximumInstanceFiles = maximumInstanceFiles
        self.completedTransactionRetention = completedTransactionRetention
        self.diagnosticRetention = diagnosticRetention
        self.staleInstanceRetention = staleInstanceRetention
        self.maximumLiveCommandFileAge = maximumLiveCommandFileAge
    }

    fileprivate var isValid: Bool {
        maximumMessageFiles > 0 &&
            maximumAggregateMessageBytes >= FileExchange.maximumMessageBytes &&
            maximumInstanceFiles > 0 &&
            completedTransactionRetention.isFinite && completedTransactionRetention >= 0 &&
            diagnosticRetention.isFinite && diagnosticRetention >= completedTransactionRetention &&
            staleInstanceRetention.isFinite && staleInstanceRetention >= 0 &&
            maximumLiveCommandFileAge.isFinite && maximumLiveCommandFileAge > 0
    }
}

public struct MailboxMaintenanceResult: Equatable, Sendable {
    public var removedMessageEntries: Int
    public var removedInstanceEntries: Int

    public init(removedMessageEntries: Int, removedInstanceEntries: Int) {
        self.removedMessageEntries = removedMessageEntries
        self.removedInstanceEntries = removedInstanceEntries
    }
}

public struct ArtifactReservation: Equatable, Sendable {
    public let id: UUID
    public let instanceID: UUID
    public let temporaryURL: URL
    public let destinationURL: URL
    public let relativePath: String
}

/// Immutable, atomic file exchange for the signed App Group container.
/// Callers poll and perform all file work off the real-time audio thread.
public struct FileExchange: Sendable {
    public static let maximumMessageBytes = 1_048_576
    /// Current terminal payloads contain only a bounded error string or a
    /// capture descriptor, so this reservation is intentionally much smaller
    /// than arbitrary command/plan messages.
    public static let maximumTerminalResponseBytes = 32 * 1_024
    public static let maximumArtifactBytes = 128 * 1_048_576

    public let directory: URL
    public let mailboxPolicy: MailboxPolicy
    private let messagesDirectory: URL
    private let instancesDirectory: URL
    private let artifactsDirectory: URL
    private let previewsDirectory: URL
    private let mailboxLockURL: URL

    public init(directory: URL, mailboxPolicy: MailboxPolicy = MailboxPolicy()) throws {
        guard directory.isFileURL else { throw ExchangeError.invalidDirectory }
        guard mailboxPolicy.isValid else { throw ExchangeError.invalidMailboxPolicy }
        self.directory = directory.standardizedFileURL
        self.mailboxPolicy = mailboxPolicy
        messagesDirectory = self.directory.appendingPathComponent("messages", isDirectory: true)
        instancesDirectory = self.directory.appendingPathComponent("instances", isDirectory: true)
        artifactsDirectory = self.directory.appendingPathComponent("artifacts", isDirectory: true)
        previewsDirectory = self.directory.appendingPathComponent("previews", isDirectory: true)
        mailboxLockURL = self.directory.appendingPathComponent(".mailbox.lock")
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: messagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: instancesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)
        for url in [self.directory, messagesDirectory, instancesDirectory, artifactsDirectory, previewsDirectory] {
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw ExchangeError.invalidDirectory
            }
        }
        let descriptor = open(mailboxLockURL.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw ExchangeError.mailboxLockUnavailable }
        _ = fchmod(descriptor, mode_t(0o600))
        close(descriptor)
    }

    public init(
        appGroup fileManager: FileManager = .default,
        mailboxPolicy: MailboxPolicy = MailboxPolicy()
    ) throws {
        try self.init(
            directory: AppGroupContainer.exchangeRoot(fileManager: fileManager),
            mailboxPolicy: mailboxPolicy
        )
    }

    @discardableResult
    public func send(_ message: ExchangeMessage) throws -> URL {
        try message.validate()
        let encoder = JSONEncoder.exchangeEncoder
        let data = try encoder.encode(message)
        guard data.count <= Self.maximumMessageBytes else { throw ExchangeError.messageTooLarge }
        if message.isTerminalResponse,
           data.count > Self.maximumTerminalResponseBytes {
            throw ExchangeError.messageTooLarge
        }
        return try withMailboxLock {
            let destination = messageURL(id: message.id)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                let existing = try receive(id: message.id)
                guard existing == message else { throw ExchangeError.messageCollision(message.id) }
                return destination
            }
            _ = try performMaintenanceLocked(now: Date())
            let now = Date()
            let files = try mailboxFiles(in: messagesDirectory, decodeMessages: true)
            let inventory = try mailboxInventory(files: files)
            let (projectedBytes, overflow) = inventory.aggregateBytes.addingReportingOverflow(data.count)
            let outstandingAfterPublication = try unresolvedCommandCount(
                in: files,
                now: now,
                adding: message
            )
            let (reservedBytes, reservationOverflow) = Self.maximumTerminalResponseBytes
                .multipliedReportingOverflow(by: outstandingAfterPublication)
            let (reservedProjectedBytes, totalOverflow) = projectedBytes
                .addingReportingOverflow(reservedBytes)
            guard !overflow,
                  !reservationOverflow,
                  !totalOverflow,
                  inventory.entryCount < mailboxPolicy.maximumMessageFiles,
                  inventory.entryCount + outstandingAfterPublication <= mailboxPolicy.maximumMessageFiles,
                  reservedProjectedBytes <= mailboxPolicy.maximumAggregateMessageBytes else {
                throw ExchangeError.mailboxFull
            }
            let temporary = messagesDirectory.appendingPathComponent(
                ".\(message.id.uuidString).\(UUID().uuidString).tmp"
            )
            try data.write(to: temporary, options: .withoutOverwriting)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
            do { try fileManager.moveItem(at: temporary, to: destination) }
            catch {
                try? fileManager.removeItem(at: temporary)
                if fileManager.fileExists(atPath: destination.path) {
                    let existing = try receive(id: message.id)
                    guard existing == message else {
                        throw ExchangeError.messageCollision(message.id)
                    }
                    return destination
                }
                throw error
            }
            return destination
        }
    }

    public func receive(id: UUID) throws -> ExchangeMessage {
        let url = messageURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExchangeError.messageNotFound(id)
        }
        return try decodeMessage(at: url)
    }

    public func scan(instanceID: UUID? = nil, sender: ExchangePeerRole? = nil) throws -> ExchangeScan {
        var messages: [ExchangeMessage] = []
        var rejections: [ExchangeRejection] = []
        for url in try jsonFiles(in: messagesDirectory) {
            do {
                let message = try decodeMessage(at: url)
                if instanceID.map({ message.instanceID == $0 }) ?? true,
                   sender.map({ message.sender == $0 }) ?? true {
                    messages.append(message)
                }
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                continue
            } catch {
                rejections.append(.init(fileName: url.lastPathComponent, reason: String(describing: error)))
            }
        }
        messages.sort { ($0.timestamp, $0.id.uuidString) < ($1.timestamp, $1.id.uuidString) }
        return ExchangeScan(messages: messages, rejections: rejections)
    }

    public func list() throws -> [ExchangeMessage] {
        let result = try scan()
        guard result.rejections.isEmpty else {
            throw ExchangeError.malformedMessage(result.rejections[0].fileName)
        }
        return result.messages
    }

    public func publishInstance(_ record: PluginInstanceRecord) throws {
        try record.validate()
        let data = try JSONEncoder.exchangeEncoder.encode(record)
        guard data.count <= Self.maximumMessageBytes else { throw ExchangeError.messageTooLarge }
        let destination = instancesDirectory
            .appendingPathComponent(record.id.uuidString)
            .appendingPathExtension("json")
        try withMailboxLock {
            if !FileManager.default.fileExists(atPath: destination.path) {
                _ = try performMaintenanceLocked(now: Date())
                let inventory = try mailboxInventory(in: instancesDirectory)
                guard inventory.entryCount < mailboxPolicy.maximumInstanceFiles else {
                    throw ExchangeError.mailboxFull
                }
            }
            try atomicReplace(data: data, destination: destination)
        }
    }

    public func scanInstances(now: Date = Date(), activeWithin: TimeInterval = 5) throws -> InstanceScan {
        var instances: [PluginInstanceRecord] = []
        var rejections: [ExchangeRejection] = []
        for url in try jsonFiles(in: instancesDirectory) {
            do {
                let data = try boundedData(at: url, maximumBytes: Self.maximumMessageBytes)
                let record = try JSONDecoder.exchangeDecoder.decode(PluginInstanceRecord.self, from: data)
                try record.validate()
                guard url.lastPathComponent == record.id.uuidString + ".json" else {
                    throw ExchangeError.nonCanonicalMailboxEntry(url.lastPathComponent)
                }
                let age = now.timeIntervalSince(record.updatedAt)
                if age >= -1, age <= activeWithin { instances.append(record) }
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                continue
            } catch {
                rejections.append(.init(fileName: url.lastPathComponent, reason: String(describing: error)))
            }
        }
        instances.sort { ($0.updatedAt, $0.id.uuidString) > ($1.updatedAt, $1.id.uuidString) }
        return InstanceScan(instances: instances, rejections: rejections)
    }

    public func reserveWAVArtifact(instanceID: UUID, id: UUID = UUID()) throws -> ArtifactReservation {
        let instanceDirectory = artifactsDirectory.appendingPathComponent(instanceID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: instanceDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: instanceDirectory.path)
        let fileName = id.uuidString + ".wav"
        let destination = instanceDirectory.appendingPathComponent(fileName)
        let temporary = instanceDirectory.appendingPathComponent(".\(id.uuidString).\(UUID().uuidString).tmp")
        return ArtifactReservation(
            id: id,
            instanceID: instanceID,
            temporaryURL: temporary,
            destinationURL: destination,
            relativePath: "artifacts/\(instanceID.uuidString)/\(fileName)"
        )
    }

    public func publishArtifact(
        _ reservation: ArtifactReservation,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int,
        runtimeEpoch: UUID? = nil
    ) throws -> CaptureArtifact {
        let fileManager = FileManager.default
        let expectedInstanceDirectory = artifactsDirectory
            .appendingPathComponent(reservation.instanceID.uuidString, isDirectory: true)
            .standardizedFileURL
        let expectedDestination = expectedInstanceDirectory
            .appendingPathComponent(reservation.id.uuidString)
            .appendingPathExtension("wav")
            .standardizedFileURL
        guard reservation.destinationURL.standardizedFileURL == expectedDestination,
              reservation.temporaryURL.standardizedFileURL.deletingLastPathComponent() == expectedInstanceDirectory,
              reservation.temporaryURL.lastPathComponent.hasPrefix(".\(reservation.id.uuidString)."),
              reservation.temporaryURL.pathExtension == "tmp",
              reservation.relativePath == "artifacts/\(reservation.instanceID.uuidString)/\(reservation.id.uuidString).wav" else {
            throw ExchangeError.invalidArtifactPath
        }
        try rejectSymlinkComponents(from: artifactsDirectory, through: expectedInstanceDirectory)
        let values = try reservation.temporaryURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ExchangeError.invalidArtifactPath
        }
        guard let byteCount = values.fileSize, byteCount <= Self.maximumArtifactBytes else {
            throw ExchangeError.artifactTooLarge
        }
        guard !fileManager.fileExists(atPath: reservation.destinationURL.path) else {
            throw ExchangeError.messageCollision(reservation.id)
        }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: reservation.temporaryURL.path)
        try fileManager.moveItem(at: reservation.temporaryURL, to: reservation.destinationURL)
        let hash = try sha256(of: reservation.destinationURL)
        return CaptureArtifact(
            id: reservation.id,
            relativePath: reservation.relativePath,
            sha256: hash,
            sampleRate: sampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            originatingInstanceID: reservation.instanceID,
            originatingRuntimeEpoch: runtimeEpoch
        )
    }

    public func resolveArtifact(_ descriptor: CaptureArtifact, verifyHash: Bool = true) throws -> URL {
        try descriptor.validateForExchange()
        let candidate = directory.appendingPathComponent(descriptor.relativePath).standardizedFileURL
        let rootPath = artifactsDirectory.standardizedFileURL.path + "/"
        guard candidate.path.hasPrefix(rootPath) else { throw ExchangeError.invalidArtifactPath }
        try rejectSymlinkComponents(from: artifactsDirectory, through: candidate.deletingLastPathComponent())
        let values = try candidate.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ExchangeError.invalidArtifactPath
        }
        guard let byteCount = values.fileSize, byteCount <= Self.maximumArtifactBytes else {
            throw ExchangeError.artifactTooLarge
        }
        if verifyHash, try sha256(of: candidate) != descriptor.sha256 {
            throw ExchangeError.artifactHashMismatch
        }
        return candidate
    }

    public func previewDirectory(captureID: UUID, requestID: UUID = UUID()) throws -> URL {
        let root = previewsDirectory.appendingPathComponent(captureID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        return root.appendingPathComponent(requestID.uuidString, isDirectory: true)
    }

    /// Deletes only locally cached audio and preview artifacts. Heartbeats and
    /// protocol messages remain so active AU discovery and acknowledgement
    /// reconciliation are not corrupted by a privacy action.
    public func deleteAllCachedAudio() throws -> CachePurgeResult {
        let removedArtifacts = try removeContents(of: artifactsDirectory)
        let removedPreviews = try removeContents(of: previewsDirectory)
        return CachePurgeResult(
            removedArtifactEntries: removedArtifacts,
            removedPreviewEntries: removedPreviews
        )
    }

    /// Bounds durable protocol state without ever evicting a live command to
    /// admit a newer one. File modification dates—not sender-authored JSON
    /// timestamps—control retention. Call only from non-real-time work.
    public func performMailboxMaintenance(
        now: Date = Date()
    ) throws -> MailboxMaintenanceResult {
        try withMailboxLock { try performMaintenanceLocked(now: now) }
    }

    private func performMaintenanceLocked(now: Date) throws -> MailboxMaintenanceResult {
        let messageFiles = try mailboxFiles(in: messagesDirectory, decodeMessages: true)
        let decoded = messageFiles.compactMap { file -> (MailboxFile, ExchangeMessage)? in
            guard let message = file.message else { return nil }
            return (file, message)
        }
        var commands: [UUID: (MailboxFile, ExchangeMessage)] = [:]
        for (file, message) in decoded
        where message.sender == .companion && message.requiresTerminalResponse {
            if let existing = commands[message.id] {
                commands[message.id] = existing.0.modifiedAt >= file.modifiedAt
                    ? existing
                    : (file, message)
            } else {
                commands[message.id] = (file, message)
            }
        }
        var removals: Set<URL> = []
        for (_, commandEntry) in commands {
            let file = commandEntry.0
            let message = commandEntry.1
            let matchingReplies = decoded.filter { _, candidate in
                isMatchingTerminal(candidate, for: message)
            }
            if isActiveCommand(message, file: file, now: now) {
                continue
            }
            // A command held past the hard filesystem age is unsafe to execute
            // even if its sender-authored expiry claims it is still live.
            if message.expiresAt.map({ $0 >= now }) == true,
               age(of: file, at: now) >= mailboxPolicy.maximumLiveCommandFileAge {
                removals.insert(file.url)
                for reply in matchingReplies { removals.insert(reply.0.url) }
                continue
            }
            if matchingReplies.isEmpty {
                if age(of: file, at: now) >= mailboxPolicy.diagnosticRetention {
                    removals.insert(file.url)
                }
            } else {
                let completionDate = matchingReplies.reduce(file.modifiedAt) {
                    max($0, $1.0.modifiedAt)
                }
                if now.timeIntervalSince(completionDate) >=
                    mailboxPolicy.completedTransactionRetention {
                    removals.insert(file.url)
                    for reply in matchingReplies { removals.insert(reply.0.url) }
                }
            }
        }

        for (file, message) in decoded where !removals.contains(file.url) {
            if message.isTerminalResponse {
                let hasMatchingCommand = commands.values.contains { _, command in
                    isMatchingTerminal(message, for: command)
                }
                if !hasMatchingCommand,
                   age(of: file, at: now) >= mailboxPolicy.diagnosticRetention {
                    removals.insert(file.url)
                }
            } else if !(message.sender == .companion && message.requiresTerminalResponse),
                      age(of: file, at: now) >= mailboxPolicy.diagnosticRetention {
                removals.insert(file.url)
            }
        }

        // Malformed, oversized, symlink, and abandoned temporary entries count
        // against quota while retained for diagnostics, then become eligible.
        for file in messageFiles where file.message == nil {
            if age(of: file, at: now) >= mailboxPolicy.diagnosticRetention {
                removals.insert(file.url)
            }
        }
        let removedMessages = try removeEntries(removals)

        let instanceFiles = try mailboxFiles(in: instancesDirectory, decodeMessages: false)
        let staleInstances = Set(instanceFiles.compactMap { file in
            age(of: file, at: now) >= mailboxPolicy.staleInstanceRetention ? file.url : nil
        })
        let removedInstances = try removeEntries(staleInstances)
        return MailboxMaintenanceResult(
            removedMessageEntries: removedMessages,
            removedInstanceEntries: removedInstances
        )
    }

    private func age(of file: MailboxFile, at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(file.modifiedAt))
    }

    private func removeEntries(_ urls: Set<URL>) throws -> Int {
        var removed = 0
        for url in urls {
            do {
                // Never recursively remove an unexpected directory found in a
                // mailbox. A malformed directory remains a bounded diagnostic
                // entry until a user explicitly repairs the App Group.
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true || values.isSymbolicLink == true else {
                    continue
                }
                try FileManager.default.removeItem(at: url)
                removed += 1
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                continue
            }
        }
        return removed
    }

    private func mailboxInventory(in directory: URL) throws -> MailboxInventory {
        try mailboxInventory(files: mailboxFiles(in: directory, decodeMessages: false))
    }

    private func mailboxInventory(files: [MailboxFile]) throws -> MailboxInventory {
        var aggregateBytes = 0
        for file in files {
            let (sum, overflow) = aggregateBytes.addingReportingOverflow(file.byteCount)
            guard !overflow else { throw ExchangeError.mailboxFull }
            aggregateBytes = sum
        }
        return MailboxInventory(entryCount: files.count, aggregateBytes: aggregateBytes)
    }

    /// Counts terminal-response capacity still owed after atomically publishing
    /// `adding`. Every live command reserves one small reply slot and byte
    /// budget before it is accepted, so a command flood cannot make its own
    /// acknowledgement, failure, or capture descriptor impossible to write.
    private func unresolvedCommandCount(
        in files: [MailboxFile],
        now: Date,
        adding message: ExchangeMessage
    ) throws -> Int {
        let existing = files.compactMap { file -> (MailboxFile, ExchangeMessage)? in
            guard let decoded = file.message else { return nil }
            return (file, decoded)
        }
        let commands = existing.filter { file, candidate in
            isActiveCommand(candidate, file: file, now: now)
        }
        var unresolved = 0
        for (_, command) in commands {
            let terminalExists = existing.contains { _, candidate in
                isMatchingTerminal(candidate, for: command)
            } || isMatchingTerminal(message, for: command)
            if !terminalExists { unresolved += 1 }
        }
        if isActiveCommand(message, file: nil, now: now) { unresolved += 1 }
        return unresolved
    }

    private func isActiveCommand(
        _ message: ExchangeMessage,
        file: MailboxFile?,
        now: Date
    ) -> Bool {
        guard message.requiresTerminalResponse,
              let expiresAt = message.expiresAt,
              expiresAt >= now else { return false }
        if let file, age(of: file, at: now) >= mailboxPolicy.maximumLiveCommandFileAge {
            return false
        }
        return true
    }

    private func isMatchingTerminal(
        _ terminal: ExchangeMessage,
        for command: ExchangeMessage
    ) -> Bool {
        guard terminal.isTerminalResponse,
              terminal.sender == .plugin,
              terminal.correlationID == command.id,
              terminal.instanceID == command.instanceID,
              terminal.targetRuntimeEpoch == command.targetRuntimeEpoch else {
            return false
        }
        switch command.kind {
        case .captureRecentRequest:
            return terminal.kind == .captureReady || terminal.kind == .failure
        case .planCommitRequest, .globalBypassRequest:
            return terminal.kind == .acknowledgement || terminal.kind == .failure
        default:
            return false
        }
    }

    private func mailboxFiles(
        in directory: URL,
        decodeMessages: Bool
    ) throws -> [MailboxFile] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        var result: [MailboxFile] = []
        result.reserveCapacity(urls.count)
        for url in urls {
            do {
                let values = try url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ])
                let isSafeRegularFile = values.isRegularFile == true &&
                    values.isSymbolicLink != true
                let message: ExchangeMessage?
                if decodeMessages,
                   url.pathExtension.lowercased() == "json",
                   isSafeRegularFile,
                   let byteCount = values.fileSize,
                   byteCount <= Self.maximumMessageBytes {
                    message = try? decodeMessage(at: url)
                } else {
                    message = nil
                }
                result.append(MailboxFile(
                    url: url.standardizedFileURL,
                    byteCount: max(0, values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    message: message
                ))
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                continue
            }
        }
        return result
    }

    private func withMailboxLock<T>(_ operation: () throws -> T) throws -> T {
        let descriptor = open(mailboxLockURL.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw ExchangeError.mailboxLockUnavailable }
        defer { close(descriptor) }
        let deadline = Date().addingTimeInterval(0.5)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            if errno == EINTR { continue }
            guard errno == EWOULDBLOCK || errno == EAGAIN,
                  Date() < deadline else {
                throw ExchangeError.mailboxLockUnavailable
            }
            usleep(5_000)
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private func messageURL(id: UUID) -> URL {
        messagesDirectory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func decodeMessage(at url: URL) throws -> ExchangeMessage {
        let data = try boundedData(at: url, maximumBytes: Self.maximumMessageBytes)
        let message = try JSONDecoder.exchangeDecoder.decode(ExchangeMessage.self, from: data)
        try message.validate()
        guard url.deletingLastPathComponent().standardizedFileURL == messagesDirectory,
              url.lastPathComponent == message.id.uuidString + ".json" else {
            throw ExchangeError.nonCanonicalMailboxEntry(url.lastPathComponent)
        }
        return message
    }

    private func boundedData(at url: URL, maximumBytes: Int) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw ExchangeError.invalidArtifactPath }
        defer { close(descriptor) }

        var fileStatus = stat()
        guard fstat(descriptor, &fileStatus) == 0,
              (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_size >= 0 else {
            throw ExchangeError.invalidArtifactPath
        }
        let byteCount = Int(fileStatus.st_size)
        guard byteCount <= maximumBytes else {
            throw ExchangeError.messageTooLarge
        }

        var data = Data(count: byteCount)
        let completed = data.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard byteCount == 0 || rawBuffer.baseAddress != nil else { return false }
            var offset = 0
            while offset < byteCount {
                let result = Darwin.read(
                    descriptor,
                    rawBuffer.baseAddress!.advanced(by: offset),
                    byteCount - offset
                )
                if result > 0 {
                    offset += Int(result)
                } else if result == 0 {
                    return false
                } else if errno != EINTR {
                    return false
                }
            }
            return true
        }
        guard completed else { throw CocoaError(.fileReadUnknown) }

        var finalStatus = stat()
        guard fstat(descriptor, &finalStatus) == 0,
              finalStatus.st_dev == fileStatus.st_dev,
              finalStatus.st_ino == fileStatus.st_ino,
              finalStatus.st_size == fileStatus.st_size else {
            throw ExchangeError.invalidArtifactPath
        }
        return data
    }

    private func jsonFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "json" }
    }

    private func atomicReplace(data: Data, destination: URL) throws {
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .withoutOverwriting)
        let fileManager = FileManager.default
        var published = false
        defer { if !published { try? fileManager.removeItem(at: temporary) } }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
        published = true
    }

    private func removeContents(of root: URL) throws -> Int {
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw ExchangeError.invalidArtifactPath
        }
        let fileManager = FileManager.default
        let entries = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )
        var removed = 0
        for entry in entries {
            let candidate = entry.standardizedFileURL
            guard candidate.deletingLastPathComponent() == root.standardizedFileURL else {
                throw ExchangeError.invalidArtifactPath
            }
            do {
                try fileManager.removeItem(at: candidate)
                removed += 1
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                // Another product process may have completed cleanup first.
                continue
            }
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        return removed
    }

    private func sha256(of url: URL) throws -> String {
        let data = try boundedData(at: url, maximumBytes: Self.maximumArtifactBytes)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func rejectSymlinkComponents(from root: URL, through destination: URL) throws {
        let normalizedRoot = root.standardizedFileURL
        let normalizedDestination = destination.standardizedFileURL
        let rootValues = try normalizedRoot.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw ExchangeError.invalidArtifactPath
        }
        let rootPath = normalizedRoot.path
        guard normalizedDestination.path == rootPath || normalizedDestination.path.hasPrefix(rootPath + "/") else {
            throw ExchangeError.invalidArtifactPath
        }
        var current = normalizedRoot
        let relative = normalizedDestination.path.dropFirst(rootPath.count)
            .split(separator: "/")
        for component in relative {
            current.appendPathComponent(String(component), isDirectory: true)
            let values = try current.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw ExchangeError.invalidArtifactPath
            }
        }
    }
}

private struct MailboxFile {
    var url: URL
    var byteCount: Int
    var modifiedAt: Date
    var message: ExchangeMessage?
}

private struct MailboxInventory {
    var entryCount: Int
    var aggregateBytes: Int
}

private extension ExchangeMessage {
    var requiresTerminalResponse: Bool {
        switch kind {
        case .captureRecentRequest, .planCommitRequest, .globalBypassRequest:
            true
        default:
            false
        }
    }

    var isTerminalResponse: Bool {
        switch kind {
        case .captureReady, .acknowledgement, .failure:
            true
        default:
            false
        }
    }
}

private extension JSONEncoder {
    static var exchangeEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension JSONDecoder {
    static var exchangeDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

private extension CaptureArtifact {
    func validateForExchange() throws {
        // Imported/offline artifacts are legitimate analysis inputs and do not
        // have an AU runtime binding. A captureReady *message* requires both
        // origin fields; resolving an artifact only requires that its own
        // descriptor is well-formed.
        try validate()
    }
}
