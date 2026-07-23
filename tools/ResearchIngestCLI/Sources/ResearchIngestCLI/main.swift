import Foundation
import ResearchIngestion

@main
enum ResearchIngestCLI {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("research-ingest: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else { throw UsageError() }
        switch command {
        case "fetch":
            guard arguments.count == 3 else { throw UsageError() }
            let request = try loadRequest(arguments[1])
            let archive = ResearchArchive(rootURL: URL(fileURLWithPath: arguments[2], isDirectory: true))
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            let (temporaryURL, response) = try await session.download(from: request.retrievalURL)
            guard let http = response as? HTTPURLResponse else {
                throw ResearchIngestionError.invalidRequest("Retrieval did not return an HTTP response.")
            }
            let contentLength = http.expectedContentLength >= 0 ? Int(http.expectedContentLength) : nil
            let metadata = ResearchRetrievalMetadata(
                finalURL: http.url ?? request.retrievalURL,
                mediaType: http.value(forHTTPHeaderField: "Content-Type"),
                contentLength: contentLength,
                contentRange: http.value(forHTTPHeaderField: "Content-Range"),
                etag: http.value(forHTTPHeaderField: "ETag"),
                lastModified: http.value(forHTTPHeaderField: "Last-Modified")
            )
            var statusMetadata = metadata
            statusMetadata.httpStatus = http.statusCode
            let record = try archive.ingestPayload(Data(contentsOf: temporaryURL), request: request, metadata: statusMetadata)
            printRecord(record)
        case "ingest-file":
            guard arguments.count == 5 else { throw UsageError() }
            let request = try loadRequest(arguments[1])
            let inputURL = URL(fileURLWithPath: arguments[2])
            let archive = ResearchArchive(rootURL: URL(fileURLWithPath: arguments[3], isDirectory: true))
            let metadata = ResearchRetrievalMetadata(
                finalURL: request.retrievalURL,
                mediaType: arguments[4],
                contentLength: try inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
            )
            let record = try archive.ingestPayload(Data(contentsOf: inputURL), request: request, metadata: metadata)
            printRecord(record)
        case "link":
            guard arguments.count == 3 else { throw UsageError() }
            let request = try loadRequest(arguments[1])
            let archive = ResearchArchive(rootURL: URL(fileURLWithPath: arguments[2], isDirectory: true))
            printRecord(try archive.recordLinkOnly(request: request))
        case "git":
            guard arguments.count == 4 || arguments.count == 5 else { throw UsageError() }
            let request = try loadRequest(arguments[1])
            let checkoutURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let expectedCommit = arguments.count == 5 ? arguments[4] : nil
            let evidence = try GitCheckoutInspector().inspect(checkoutURL: checkoutURL, expectedCommit: expectedCommit)
            let archive = ResearchArchive(rootURL: URL(fileURLWithPath: arguments[3], isDirectory: true))
            printRecord(try archive.recordGitCheckout(request: request, evidence: evidence))
        default:
            throw UsageError()
        }
    }

    private static func loadRequest(_ path: String) throws -> ResearchIngestionRequest {
        try JSONDecoder().decode(
            ResearchIngestionRequest.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
    }

    private static func printRecord(_ record: ResearchCaptureRecord) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(record), let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }
}

private struct UsageError: Error, CustomStringConvertible {
    var description: String {
        """
        usage:
          ResearchIngestCLI fetch REQUEST.json ARCHIVE_ROOT
          ResearchIngestCLI ingest-file REQUEST.json INPUT ARCHIVE_ROOT MEDIA_TYPE
          ResearchIngestCLI link REQUEST.json ARCHIVE_ROOT
          ResearchIngestCLI git REQUEST.json CHECKOUT ARCHIVE_ROOT [EXPECTED_COMMIT]
        """
    }
}
