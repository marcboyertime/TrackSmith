import CryptoKit
import Foundation
import PDFKit

public enum ResearchCaptureMode: String, Codable, CaseIterable, Sendable {
    case pdf
    case html
    case text
    case binary
    case gitCheckout
    case linkAndNotes
}

public enum ResearchHandlingClass: String, Codable, CaseIterable, Sendable {
    case redistributable
    case internalReference
    case linkAndNotes
    case licenseReviewRequired
}

public enum ResearchLicenseStatus: String, Codable, CaseIterable, Sendable {
    case verified
    case internalUseOnly
    case unknown
    case reviewRequired
}

public enum CanonicalReplacementPolicy: String, Codable, CaseIterable, Sendable {
    /// An already accepted resource ID may only resolve to the same payload.
    case rejectDifferentPayload
    /// A changed publisher payload is accepted only with a new document version
    /// and a human-written replacement reason.
    case appendNewDocumentVersion
    /// An explicit canonical source may supersede a named noncanonical hash.
    case supersedeNamedNoncanonicalPayload
}

public struct ResearchIngestionRequest: Codable, Equatable, Sendable {
    public var resourceID: String
    public var title: String
    public var publisherOrAuthors: String
    public var evidenceRole: String
    public var canonicalURL: URL
    public var retrievalURL: URL
    public var sourceVersion: String
    public var captureMode: ResearchCaptureMode
    public var expectedMediaTypes: [String]
    public var minimumByteCount: Int
    public var minimumPageCount: Int
    public var minimumUsefulTextCharacters: Int
    public var requiresExtractableText: Bool
    public var handlingClass: ResearchHandlingClass
    public var rightsBasis: String
    public var licenseStatus: ResearchLicenseStatus
    public var licenseSPDX: String?
    public var localUseOnly: Bool
    public var replacementPolicy: CanonicalReplacementPolicy
    public var supersedesSHA256: String?
    public var replacementReason: String?
    public var notes: String

    public init(
        resourceID: String,
        title: String,
        publisherOrAuthors: String,
        evidenceRole: String,
        canonicalURL: URL,
        retrievalURL: URL,
        sourceVersion: String,
        captureMode: ResearchCaptureMode,
        expectedMediaTypes: [String],
        minimumByteCount: Int = 1_024,
        minimumPageCount: Int = 1,
        minimumUsefulTextCharacters: Int = 200,
        requiresExtractableText: Bool = true,
        handlingClass: ResearchHandlingClass,
        rightsBasis: String,
        licenseStatus: ResearchLicenseStatus,
        licenseSPDX: String? = nil,
        localUseOnly: Bool,
        replacementPolicy: CanonicalReplacementPolicy = .rejectDifferentPayload,
        supersedesSHA256: String? = nil,
        replacementReason: String? = nil,
        notes: String = ""
    ) {
        self.resourceID = resourceID
        self.title = title
        self.publisherOrAuthors = publisherOrAuthors
        self.evidenceRole = evidenceRole
        self.canonicalURL = canonicalURL
        self.retrievalURL = retrievalURL
        self.sourceVersion = sourceVersion
        self.captureMode = captureMode
        self.expectedMediaTypes = expectedMediaTypes
        self.minimumByteCount = minimumByteCount
        self.minimumPageCount = minimumPageCount
        self.minimumUsefulTextCharacters = minimumUsefulTextCharacters
        self.requiresExtractableText = requiresExtractableText
        self.handlingClass = handlingClass
        self.rightsBasis = rightsBasis
        self.licenseStatus = licenseStatus
        self.licenseSPDX = licenseSPDX
        self.localUseOnly = localUseOnly
        self.replacementPolicy = replacementPolicy
        self.supersedesSHA256 = supersedesSHA256
        self.replacementReason = replacementReason
        self.notes = notes
    }
}

public struct ResearchRetrievalMetadata: Codable, Equatable, Sendable {
    public var retrievedAtUTC: Date
    public var httpStatus: Int?
    public var finalURL: URL
    public var mediaType: String?
    public var contentLength: Int?
    public var contentRange: String?
    public var etag: String?
    public var lastModified: String?

    public init(
        retrievedAtUTC: Date = Date(),
        httpStatus: Int? = nil,
        finalURL: URL,
        mediaType: String?,
        contentLength: Int? = nil,
        contentRange: String? = nil,
        etag: String? = nil,
        lastModified: String? = nil
    ) {
        self.retrievedAtUTC = retrievedAtUTC
        self.httpStatus = httpStatus
        self.finalURL = finalURL
        self.mediaType = mediaType
        self.contentLength = contentLength
        self.contentRange = contentRange
        self.etag = etag
        self.lastModified = lastModified
    }
}

public enum ResearchCaptureStatus: String, Codable, CaseIterable, Sendable {
    case accepted
    case duplicate
    case quarantined
    case linkOnly
    case gitPinned
}

public enum ResearchQualityStatus: String, Codable, CaseIterable, Sendable {
    case validated
    case rejected
    case metadataOnly
}

public struct ResearchCaptureRecord: Codable, Equatable, Sendable {
    public var manifestVersion: String
    public var auditID: UUID
    public var resourceID: String
    public var title: String
    public var publisherOrAuthors: String
    public var evidenceRole: String
    public var canonicalURL: URL
    public var retrievalURL: URL
    public var sourceVersion: String
    public var retrievedAtUTC: Date
    public var captureMode: ResearchCaptureMode
    public var handlingClass: ResearchHandlingClass
    public var rightsBasis: String
    public var licenseStatus: ResearchLicenseStatus
    public var licenseSPDX: String?
    public var localUseOnly: Bool
    public var httpStatus: Int?
    public var finalURL: URL
    public var mediaType: String?
    public var byteCount: Int?
    public var sha256: String?
    public var etag: String?
    public var lastModified: String?
    public var gitCommit: String?
    public var gitRemoteURL: String?
    public var localPath: String?
    public var supersedesSHA256: String?
    public var captureStatus: ResearchCaptureStatus
    public var qualityStatus: ResearchQualityStatus
    public var qualityFindings: [String]
    public var notes: String

    public init(
        request: ResearchIngestionRequest,
        metadata: ResearchRetrievalMetadata,
        byteCount: Int? = nil,
        sha256: String? = nil,
        gitCommit: String? = nil,
        gitRemoteURL: String? = nil,
        localPath: String? = nil,
        supersedesSHA256: String? = nil,
        captureStatus: ResearchCaptureStatus,
        qualityStatus: ResearchQualityStatus,
        qualityFindings: [String]
    ) {
        manifestVersion = "1.0"
        auditID = UUID()
        resourceID = request.resourceID
        title = request.title
        publisherOrAuthors = request.publisherOrAuthors
        evidenceRole = request.evidenceRole
        canonicalURL = request.canonicalURL
        retrievalURL = request.retrievalURL
        sourceVersion = request.sourceVersion
        retrievedAtUTC = metadata.retrievedAtUTC
        captureMode = request.captureMode
        handlingClass = request.handlingClass
        rightsBasis = request.rightsBasis
        licenseStatus = request.licenseStatus
        licenseSPDX = request.licenseSPDX
        localUseOnly = request.localUseOnly
        httpStatus = metadata.httpStatus
        finalURL = metadata.finalURL
        mediaType = metadata.mediaType
        self.byteCount = byteCount
        self.sha256 = sha256
        etag = metadata.etag
        lastModified = metadata.lastModified
        self.gitCommit = gitCommit
        self.gitRemoteURL = gitRemoteURL
        self.localPath = localPath
        self.supersedesSHA256 = supersedesSHA256
        self.captureStatus = captureStatus
        self.qualityStatus = qualityStatus
        self.qualityFindings = qualityFindings
        notes = request.notes
    }
}

public enum ResearchIngestionError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidRequest(String)
    case unexpectedHTTPStatus(Int)
    case partialDownload(String)
    case contentLengthMismatch(expected: Int, actual: Int)
    case mediaTypeMismatch(expected: [String], actual: String?)
    case insufficientBytes(minimum: Int, actual: Int)
    case corruptPDF(String)
    case unusableHTML(String)
    case unusableText(String)
    case changedPayloadRequiresPolicy(previous: String, candidate: String)
    case invalidReplacementPolicy(String)
    case gitCheckoutInvalid(String)
    case archiveIO(String)

    public var description: String {
        switch self {
        case let .invalidRequest(message), let .unusableHTML(message), let .unusableText(message),
             let .corruptPDF(message), let .invalidReplacementPolicy(message),
             let .gitCheckoutInvalid(message), let .archiveIO(message): message
        case let .unexpectedHTTPStatus(status): "Unexpected HTTP status \(status)."
        case let .partialDownload(detail): "Partial download rejected: \(detail)."
        case let .contentLengthMismatch(expected, actual): "Content-Length \(expected) did not match \(actual) received bytes."
        case let .mediaTypeMismatch(expected, actual): "Expected media type \(expected.joined(separator: ", ")); received \(actual ?? "none")."
        case let .insufficientBytes(minimum, actual): "Payload has \(actual) bytes; minimum is \(minimum)."
        case let .changedPayloadRequiresPolicy(previous, candidate): "Resource payload changed from \(previous) to \(candidate) without an admissible replacement policy."
        }
    }
}

public struct ResearchPayloadValidation: Equatable, Sendable {
    public var normalizedMediaType: String
    public var usefulTextCharacterCount: Int?
    public var pageCount: Int?
    public var findings: [String]
}

public struct ResearchPayloadValidator: Sendable {
    public init() {}

    public func validate(
        _ data: Data,
        request: ResearchIngestionRequest,
        metadata: ResearchRetrievalMetadata
    ) throws -> ResearchPayloadValidation {
        try Self.validateRequest(request)
        if let status = metadata.httpStatus {
            guard status == 200 else {
                if status == 206 { throw ResearchIngestionError.partialDownload("HTTP 206 Partial Content") }
                throw ResearchIngestionError.unexpectedHTTPStatus(status)
            }
        }
        if let range = metadata.contentRange, !range.isEmpty {
            throw ResearchIngestionError.partialDownload("Content-Range header was present: \(range)")
        }
        if let expectedLength = metadata.contentLength, expectedLength != data.count {
            throw ResearchIngestionError.contentLengthMismatch(expected: expectedLength, actual: data.count)
        }
        guard data.count >= request.minimumByteCount else {
            throw ResearchIngestionError.insufficientBytes(minimum: request.minimumByteCount, actual: data.count)
        }
        let mediaType = Self.normalizedMediaType(metadata.mediaType)
        let allowedTypes = request.expectedMediaTypes.map(Self.normalizedMediaType)
        guard !mediaType.isEmpty, allowedTypes.contains(mediaType) else {
            throw ResearchIngestionError.mediaTypeMismatch(
                expected: request.expectedMediaTypes,
                actual: metadata.mediaType
            )
        }

        switch request.captureMode {
        case .pdf:
            return try validatePDF(data, request: request, mediaType: mediaType)
        case .html:
            return try validateHTML(data, request: request, mediaType: mediaType)
        case .text:
            return try validateText(data, request: request, mediaType: mediaType)
        case .binary:
            return .init(
                normalizedMediaType: mediaType,
                usefulTextCharacterCount: nil,
                pageCount: nil,
                findings: ["Byte count and declared media type validated; binary semantics require a format-specific downstream validator."]
            )
        case .gitCheckout, .linkAndNotes:
            throw ResearchIngestionError.invalidRequest("\(request.captureMode.rawValue) is metadata-only and cannot accept an HTTP payload.")
        }
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func validateRequest(_ request: ResearchIngestionRequest) throws {
        guard request.resourceID.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$"#, options: .regularExpression) != nil else {
            throw ResearchIngestionError.invalidRequest("resource_id must be 3-128 safe ASCII identifier characters.")
        }
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.publisherOrAuthors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.evidenceRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.sourceVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.rightsBasis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ResearchIngestionError.invalidRequest("Title, source identity, evidence role, version, and rights basis are required.")
        }
        for url in [request.canonicalURL, request.retrievalURL] {
            guard let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil else {
                throw ResearchIngestionError.invalidRequest("Canonical and retrieval URLs must be absolute HTTP(S) URLs.")
            }
        }
        guard request.minimumByteCount >= 1,
              request.minimumPageCount >= 1,
              request.minimumUsefulTextCharacters >= 0 else {
            throw ResearchIngestionError.invalidRequest("Quality thresholds must be nonnegative and page count must be at least one.")
        }
        if request.handlingClass == .redistributable {
            guard request.licenseStatus == .verified,
                  request.licenseSPDX?.isEmpty == false,
                  !request.localUseOnly else {
                throw ResearchIngestionError.invalidRequest("Redistributable captures require a verified SPDX license and cannot be local-use-only.")
            }
        }
    }

    private func validatePDF(
        _ data: Data,
        request: ResearchIngestionRequest,
        mediaType: String
    ) throws -> ResearchPayloadValidation {
        guard data.starts(with: Data("%PDF-".utf8)) else {
            throw ResearchIngestionError.corruptPDF("PDF media type did not have a PDF file signature.")
        }
        guard let tail = String(data: data.suffix(min(data.count, 4_096)), encoding: .isoLatin1),
              tail.contains("%%EOF") else {
            throw ResearchIngestionError.partialDownload("PDF end-of-file marker was absent from the final 4096 bytes")
        }
        guard let document = PDFDocument(data: data), document.pageCount >= request.minimumPageCount else {
            throw ResearchIngestionError.corruptPDF("PDFKit could not parse the document or it had too few pages.")
        }
        let sampledPageCount = min(document.pageCount, 12)
        let usefulText = (0..<sampledPageCount).compactMap { document.page(at: $0)?.string }.joined(separator: " ")
        if request.requiresExtractableText, usefulText.nonWhitespaceCount < request.minimumUsefulTextCharacters {
            throw ResearchIngestionError.corruptPDF(
                "PDF parsed but sampled pages exposed only \(usefulText.nonWhitespaceCount) useful text characters."
            )
        }
        return .init(
            normalizedMediaType: mediaType,
            usefulTextCharacterCount: usefulText.nonWhitespaceCount,
            pageCount: document.pageCount,
            findings: ["PDF signature, EOF marker, parser, page count, and sampled text checks passed."]
        )
    }

    private func validateHTML(
        _ data: Data,
        request: ResearchIngestionRequest,
        mediaType: String
    ) throws -> ResearchPayloadValidation {
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ResearchIngestionError.unusableHTML("HTML payload was not decodable text.")
        }
        let lower = html.lowercased()
        guard lower.contains("<html") || lower.contains("<!doctype html") else {
            throw ResearchIngestionError.unusableHTML("HTML media type lacked an HTML document root.")
        }
        let shellMarkers = [
            "enable javascript to continue", "javascript is required", "just a moment...",
            "checking your browser", "access denied", "request unsuccessful",
        ]
        let visible = Self.visibleHTMLText(html)
        if shellMarkers.contains(where: lower.contains), visible.nonWhitespaceCount < max(1_000, request.minimumUsefulTextCharacters * 3) {
            throw ResearchIngestionError.unusableHTML("HTML matched an error, bot-check, or JavaScript-shell marker.")
        }
        guard visible.nonWhitespaceCount >= request.minimumUsefulTextCharacters else {
            throw ResearchIngestionError.unusableHTML(
                "HTML exposed only \(visible.nonWhitespaceCount) useful text characters after scripts and markup were removed."
            )
        }
        return .init(
            normalizedMediaType: mediaType,
            usefulTextCharacterCount: visible.nonWhitespaceCount,
            pageCount: nil,
            findings: ["HTML root, useful-text threshold, and shell/error checks passed."]
        )
    }

    private func validateText(
        _ data: Data,
        request: ResearchIngestionRequest,
        mediaType: String
    ) throws -> ResearchPayloadValidation {
        guard let text = String(data: data, encoding: .utf8),
              text.nonWhitespaceCount >= request.minimumUsefulTextCharacters else {
            throw ResearchIngestionError.unusableText("Text payload was invalid UTF-8 or below the useful-text threshold.")
        }
        return .init(
            normalizedMediaType: mediaType,
            usefulTextCharacterCount: text.nonWhitespaceCount,
            pageCount: nil,
            findings: ["UTF-8 and useful-text threshold checks passed."]
        )
    }

    private static func normalizedMediaType(_ value: String?) -> String {
        guard let value else { return "" }
        let values = value.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.split(separator: ";", maxSplits: 1).first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
        }
        guard let first = values.first, !first.isEmpty else { return "" }
        if values.allSatisfy({ $0 == first }) {
            return first
        }
        // Content-Type is not a list-valued header. Preserve conflicting
        // repeated values as a non-allowlisted identity so validation fails
        // closed, while tolerating identical values combined by URLSession.
        return values.joined(separator: ",")
    }

    private static func visibleHTMLText(_ html: String) -> String {
        var result = html
        for pattern in [#"(?is)<script\b[^>]*>.*?</script>"#, #"(?is)<style\b[^>]*>.*?</style>"#, #"(?is)<noscript\b[^>]*>.*?</noscript>"#, #"(?is)<!--.*?-->"#, #"(?is)<[^>]+>"#] {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        for (entity, replacement) in [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"),
        ] {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        return result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

public struct GitCheckoutEvidence: Codable, Equatable, Sendable {
    public var commit: String
    public var remoteURL: String
    public var checkoutWasClean: Bool

    public init(commit: String, remoteURL: String, checkoutWasClean: Bool) {
        self.commit = commit
        self.remoteURL = remoteURL
        self.checkoutWasClean = checkoutWasClean
    }
}

public struct GitCheckoutInspector: Sendable {
    public init() {}

    public func inspect(checkoutURL: URL, expectedCommit: String? = nil) throws -> GitCheckoutEvidence {
        guard checkoutURL.isFileURL else {
            throw ResearchIngestionError.gitCheckoutInvalid("Git checkout must be a local file URL.")
        }
        let commit = try runGit(["rev-parse", "HEAD"], at: checkoutURL)
        guard commit.range(of: #"^[0-9a-f]{40,64}$"#, options: .regularExpression) != nil else {
            throw ResearchIngestionError.gitCheckoutInvalid("Git HEAD was not an immutable full object ID.")
        }
        if let expectedCommit, commit != expectedCommit.lowercased() {
            throw ResearchIngestionError.gitCheckoutInvalid("Git HEAD \(commit) did not match pinned commit \(expectedCommit).")
        }
        let status = try runGit(["status", "--porcelain=v1", "--untracked-files=all"], at: checkoutURL, allowEmpty: true)
        guard status.isEmpty else {
            throw ResearchIngestionError.gitCheckoutInvalid("Mutable or dirty Git checkout rejected; archive an immutable clean commit instead.")
        }
        let remote = try runGit(["remote", "get-url", "origin"], at: checkoutURL)
        guard !remote.isEmpty else {
            throw ResearchIngestionError.gitCheckoutInvalid("Git checkout had no origin remote provenance.")
        }
        return .init(commit: commit, remoteURL: remote, checkoutWasClean: true)
    }

    private func runGit(_ arguments: [String], at checkoutURL: URL, allowEmpty: Bool = false) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", checkoutURL.path] + arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() } catch {
            throw ResearchIngestionError.gitCheckoutInvalid("Could not execute git: \(error)")
        }
        process.waitUntilExit()
        let stdout = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw ResearchIngestionError.gitCheckoutInvalid(stderr.isEmpty ? "Git command failed." : stderr)
        }
        if !allowEmpty, stdout.isEmpty {
            throw ResearchIngestionError.gitCheckoutInvalid("Git command returned no provenance value.")
        }
        return stdout
    }
}

private extension String {
    var nonWhitespaceCount: Int { unicodeScalars.reduce(0) { $0 + (CharacterSet.whitespacesAndNewlines.contains($1) ? 0 : 1) } }
}
