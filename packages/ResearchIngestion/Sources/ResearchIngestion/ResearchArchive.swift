import Foundation

public struct ResearchArchive {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    @discardableResult
    public func ingestPayload(
        _ data: Data,
        request: ResearchIngestionRequest,
        metadata: ResearchRetrievalMetadata
    ) throws -> ResearchCaptureRecord {
        try prepareDirectories()
        let hash = ResearchPayloadValidator.sha256(data)
        let validation: ResearchPayloadValidation
        do {
            validation = try ResearchPayloadValidator().validate(data, request: request, metadata: metadata)
        } catch {
            let relativePath = try quarantine(data, hash: hash, extension: extensionFor(request.captureMode))
            let record = ResearchCaptureRecord(
                request: request,
                metadata: metadata,
                byteCount: data.count,
                sha256: hash,
                localPath: relativePath,
                captureStatus: .quarantined,
                qualityStatus: .rejected,
                qualityFindings: [String(describing: error)]
            )
            try appendAuditRecord(record)
            throw error
        }

        let previous = try currentRecord(resourceID: request.resourceID)
        if let previous, previous.sha256 == hash {
            let record = ResearchCaptureRecord(
                request: request,
                metadata: metadata,
                byteCount: data.count,
                sha256: hash,
                localPath: previous.localPath,
                captureStatus: .duplicate,
                qualityStatus: .validated,
                qualityFindings: validation.findings + ["Exact payload hash was already present; object bytes were not rewritten."]
            )
            try appendAuditRecord(record)
            return record
        }

        if let previous, let previousHash = previous.sha256 {
            do {
                try validateReplacement(request: request, previous: previous, candidateHash: hash)
            } catch {
                let relativePath = try quarantine(data, hash: hash, extension: extensionFor(request.captureMode))
                let record = ResearchCaptureRecord(
                    request: request,
                    metadata: metadata,
                    byteCount: data.count,
                    sha256: hash,
                    localPath: relativePath,
                    supersedesSHA256: previousHash,
                    captureStatus: .quarantined,
                    qualityStatus: .rejected,
                    qualityFindings: [String(describing: error)]
                )
                try appendAuditRecord(record)
                throw error
            }
        }

        let relativePath = "objects/\(hash).\(extensionFor(request.captureMode))"
        let objectURL = rootURL.appendingPathComponent(relativePath)
        if !fileManager.fileExists(atPath: objectURL.path) {
            try atomicWrite(data, to: objectURL)
        }
        let record = ResearchCaptureRecord(
            request: request,
            metadata: metadata,
            byteCount: data.count,
            sha256: hash,
            localPath: relativePath,
            supersedesSHA256: previous?.sha256,
            captureStatus: .accepted,
            qualityStatus: .validated,
            qualityFindings: validation.findings
        )
        try appendAuditRecord(record)
        try publishCurrentRecord(record)
        return record
    }

    @discardableResult
    public func recordLinkOnly(
        request: ResearchIngestionRequest,
        retrievedAtUTC: Date = Date()
    ) throws -> ResearchCaptureRecord {
        try ResearchPayloadValidator.validateRequest(request)
        guard request.captureMode == .linkAndNotes,
              request.handlingClass == .linkAndNotes else {
            throw ResearchIngestionError.invalidRequest("Link-only records require linkAndNotes capture and handling classes.")
        }
        try prepareDirectories()
        let metadata = ResearchRetrievalMetadata(
            retrievedAtUTC: retrievedAtUTC,
            finalURL: request.retrievalURL,
            mediaType: nil
        )
        let record = ResearchCaptureRecord(
            request: request,
            metadata: metadata,
            captureStatus: .linkOnly,
            qualityStatus: .metadataOnly,
            qualityFindings: ["No source payload was mirrored; canonical metadata and original notes were retained."]
        )
        try appendAuditRecord(record)
        try publishCurrentRecord(record)
        return record
    }

    @discardableResult
    public func recordGitCheckout(
        request: ResearchIngestionRequest,
        evidence: GitCheckoutEvidence,
        retrievedAtUTC: Date = Date()
    ) throws -> ResearchCaptureRecord {
        try ResearchPayloadValidator.validateRequest(request)
        guard request.captureMode == .gitCheckout else {
            throw ResearchIngestionError.invalidRequest("Git evidence requires gitCheckout capture mode.")
        }
        guard evidence.checkoutWasClean,
              evidence.commit.range(of: #"^[0-9a-f]{40,64}$"#, options: .regularExpression) != nil else {
            throw ResearchIngestionError.gitCheckoutInvalid("Only a clean checkout at a full immutable commit may be recorded.")
        }
        let normalizedRemote = normalizedRepositoryURL(evidence.remoteURL)
        let declaredRepositories = [request.canonicalURL.absoluteString, request.retrievalURL.absoluteString]
            .map(normalizedRepositoryURL)
        guard declaredRepositories.contains(normalizedRemote) else {
            throw ResearchIngestionError.gitCheckoutInvalid(
                "Git origin \(evidence.remoteURL) did not match the declared canonical or retrieval URL."
            )
        }
        try prepareDirectories()
        let metadata = ResearchRetrievalMetadata(
            retrievedAtUTC: retrievedAtUTC,
            finalURL: request.retrievalURL,
            mediaType: "application/vnd.git"
        )
        let record = ResearchCaptureRecord(
            request: request,
            metadata: metadata,
            gitCommit: evidence.commit,
            gitRemoteURL: evidence.remoteURL,
            captureStatus: .gitPinned,
            qualityStatus: .metadataOnly,
            qualityFindings: ["Clean checkout and immutable full commit were verified; the mutable working tree was not copied into the archive."]
        )
        try appendAuditRecord(record)
        try publishCurrentRecord(record)
        return record
    }

    public func currentRecord(resourceID: String) throws -> ResearchCaptureRecord? {
        guard resourceID.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$"#, options: .regularExpression) != nil else {
            throw ResearchIngestionError.invalidRequest("Unsafe resource ID cannot be resolved from the archive.")
        }
        let url = rootURL.appendingPathComponent("manifests/current/\(resourceID).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            return try Self.decoder.decode(ResearchCaptureRecord.self, from: Data(contentsOf: url))
        } catch {
            throw ResearchIngestionError.archiveIO("Current manifest for \(resourceID) was unreadable: \(error)")
        }
    }

    private func validateReplacement(
        request: ResearchIngestionRequest,
        previous: ResearchCaptureRecord,
        candidateHash: String
    ) throws {
        guard let previousHash = previous.sha256 else { return }
        switch request.replacementPolicy {
        case .rejectDifferentPayload:
            throw ResearchIngestionError.changedPayloadRequiresPolicy(previous: previousHash, candidate: candidateHash)
        case .appendNewDocumentVersion:
            guard request.sourceVersion != previous.sourceVersion,
                  let reason = request.replacementReason?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !reason.isEmpty else {
                throw ResearchIngestionError.invalidReplacementPolicy(
                    "Appending a changed publisher payload requires a changed source_version and a replacement reason."
                )
            }
        case .supersedeNamedNoncanonicalPayload:
            guard request.supersedesSHA256 == previousHash,
                  let reason = request.replacementReason?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !reason.isEmpty else {
                throw ResearchIngestionError.invalidReplacementPolicy(
                    "Canonical replacement must name the exact superseded SHA-256 and record a reason."
                )
            }
        }
    }

    private func prepareDirectories() throws {
        do {
            for relative in ["objects", "quarantine", "manifests/history", "manifests/current"] {
                try fileManager.createDirectory(
                    at: rootURL.appendingPathComponent(relative),
                    withIntermediateDirectories: true
                )
            }
        } catch {
            throw ResearchIngestionError.archiveIO("Could not initialize research archive: \(error)")
        }
    }

    private func quarantine(_ data: Data, hash: String, extension fileExtension: String) throws -> String {
        let relativePath = "quarantine/\(hash).\(fileExtension)"
        let url = rootURL.appendingPathComponent(relativePath)
        if !fileManager.fileExists(atPath: url.path) { try atomicWrite(data, to: url) }
        return relativePath
    }

    private func appendAuditRecord(_ record: ResearchCaptureRecord) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: record.retrievedAtUTC)
            .replacingOccurrences(of: ":", with: "-")
        let safeResourceID = record.resourceID
            .filter { $0.isLetter || $0.isNumber || "._-".contains($0) }
            .prefix(128)
        let auditResourceID = safeResourceID.isEmpty ? "invalid-resource" : String(safeResourceID)
        let url = rootURL.appendingPathComponent(
            "manifests/history/\(timestamp)-\(auditResourceID)-\(record.auditID.uuidString.lowercased()).json"
        )
        try atomicWrite(try Self.encoder.encode(record), to: url)
    }

    private func publishCurrentRecord(_ record: ResearchCaptureRecord) throws {
        let url = rootURL.appendingPathComponent("manifests/current/\(record.resourceID).json")
        try atomicReplace(try Self.encoder.encode(record), at: url)
    }

    private func atomicWrite(_ data: Data, to destination: URL) throws {
        guard !fileManager.fileExists(atPath: destination.path) else { return }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temporary, options: [.withoutOverwriting])
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw ResearchIngestionError.archiveIO("Atomic archive publication failed: \(error)")
        }
    }

    private func atomicReplace(_ data: Data, at destination: URL) throws {
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw ResearchIngestionError.archiveIO("Atomic current-manifest publication failed: \(error)")
        }
    }

    private func extensionFor(_ mode: ResearchCaptureMode) -> String {
        switch mode {
        case .pdf: "pdf"
        case .html: "html"
        case .text: "txt"
        case .binary: "bin"
        case .gitCheckout: "git"
        case .linkAndNotes: "url"
        }
    }

    private func normalizedRepositoryURL(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while result.hasSuffix("/") { result.removeLast() }
        if result.hasSuffix(".git") { result.removeLast(4) }
        return result
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
