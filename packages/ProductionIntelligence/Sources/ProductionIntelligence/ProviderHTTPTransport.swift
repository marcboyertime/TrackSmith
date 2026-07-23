import AgentCore
import Foundation

public struct ProviderHTTPRequest: Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data
    public var timeoutSeconds: Double

    public init(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data,
        timeoutSeconds: Double
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct ProviderHTTPResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public protocol ProviderHTTPTransport: Sendable {
    func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse
}

private final class ProviderResponseDeadlineState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProviderHTTPResponse, Error>?
    private var operation: Task<Void, Never>?
    private var timeoutWorkItem: DispatchWorkItem?
    private var pendingResult: Result<ProviderHTTPResponse, Error>?
    private var finished = false

    func install(
        continuation: CheckedContinuation<ProviderHTTPResponse, Error>,
        operation: Task<Void, Never>,
        timeoutWorkItem: DispatchWorkItem
    ) -> Bool {
        lock.lock()
        if finished {
            let result = pendingResult
            pendingResult = nil
            lock.unlock()
            operation.cancel()
            timeoutWorkItem.cancel()
            if let result { continuation.resume(with: result) }
            return false
        }
        self.continuation = continuation
        self.operation = operation
        self.timeoutWorkItem = timeoutWorkItem
        lock.unlock()
        return true
    }

    func resolve(_ result: Result<ProviderHTTPResponse, Error>, cancelOperation: Bool) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = continuation
        let operation = operation
        let timeout = timeoutWorkItem
        self.continuation = nil
        self.operation = nil
        timeoutWorkItem = nil
        if continuation == nil { pendingResult = result }
        lock.unlock()

        timeout?.cancel()
        if cancelOperation { operation?.cancel() }
        continuation?.resume(with: result)
    }
}

enum ProviderTransportDeadline {
    static func send(
        using transport: any ProviderHTTPTransport,
        request: ProviderHTTPRequest
    ) async throws -> ProviderHTTPResponse {
        let state = ProviderResponseDeadlineState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let operation = Task {
                    do {
                        state.resolve(
                            .success(try await transport.send(request)),
                            cancelOperation: false
                        )
                    } catch {
                        state.resolve(.failure(error), cancelOperation: false)
                    }
                }
                let timeout = DispatchWorkItem {
                    state.resolve(.failure(URLError(.timedOut)), cancelOperation: true)
                }
                guard state.install(
                    continuation: continuation,
                    operation: operation,
                    timeoutWorkItem: timeout
                ) else { return }
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + min(max(request.timeoutSeconds, 1), 60),
                    execute: timeout
                )
            }
        } onCancel: {
            state.resolve(.failure(CancellationError()), cancelOperation: true)
        }
    }
}

private final class URLSessionRequestState: @unchecked Sendable {
    typealias Payload = (Data, URLResponse)

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Payload, Error>?
    private var dataTask: URLSessionDataTask?
    private var timeoutWorkItem: DispatchWorkItem?
    private var pendingResult: Result<Payload, Error>?
    private var finished = false

    /// Returns false when cancellation won the race before installation.
    func install(
        continuation: CheckedContinuation<Payload, Error>,
        dataTask: URLSessionDataTask,
        timeoutWorkItem: DispatchWorkItem
    ) -> Bool {
        lock.lock()
        if finished {
            let result = pendingResult
            pendingResult = nil
            lock.unlock()
            dataTask.cancel()
            timeoutWorkItem.cancel()
            if let result { continuation.resume(with: result) }
            return false
        }
        self.continuation = continuation
        self.dataTask = dataTask
        self.timeoutWorkItem = timeoutWorkItem
        lock.unlock()
        return true
    }

    func resolve(_ result: Result<Payload, Error>, cancelDataTask: Bool) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = continuation
        let task = dataTask
        let timeout = timeoutWorkItem
        self.continuation = nil
        dataTask = nil
        timeoutWorkItem = nil
        if continuation == nil { pendingResult = result }
        lock.unlock()

        timeout?.cancel()
        if cancelDataTask { task?.cancel() }
        continuation?.resume(with: result)
    }
}

public final class URLSessionProviderHTTPTransport: ProviderHTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public convenience init() {
        self.init(urlProtocolClasses: [])
    }

    public init(urlProtocolClasses: [AnyClass]) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 30
        // Provider requests remain individually bounded to at most 60 seconds.
        // Keep the session resource ceiling just above that bound so it does
        // not silently preempt a caller's explicit timeout budget.
        configuration.timeoutIntervalForResource = 65
        if !urlProtocolClasses.isEmpty {
            // Test-only protocol injection exercises deadline/cancellation
            // behavior without provider credentials or external networking.
            configuration.protocolClasses = urlProtocolClasses
        }
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeoutSeconds
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        for (name, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: name) }
        let state = URLSessionRequestState()
        let (data, response) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let dataTask = session.dataTask(with: urlRequest) { data, response, error in
                    if let error {
                        state.resolve(.failure(error), cancelDataTask: false)
                    } else if let data, let response {
                        state.resolve(.success((data, response)), cancelDataTask: false)
                    } else {
                        state.resolve(.failure(URLError(.badServerResponse)), cancelDataTask: false)
                    }
                }
                let timeout = DispatchWorkItem {
                    state.resolve(.failure(URLError(.timedOut)), cancelDataTask: true)
                }
                guard state.install(
                    continuation: continuation,
                    dataTask: dataTask,
                    timeoutWorkItem: timeout
                ) else { return }
                dataTask.resume()
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + min(max(request.timeoutSeconds, 1), 60),
                    execute: timeout
                )
            }
        } onCancel: {
            state.resolve(.failure(CancellationError()), cancelDataTask: true)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ModelProviderFailure.network("The provider returned a non-HTTP response.")
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            guard let key = key as? String else { continue }
            // Only return metadata needed for bounded retry behavior. This
            // avoids carrying cookies or provider diagnostics into logs/state.
            if key.caseInsensitiveCompare("Retry-After") == .orderedSame {
                headers["retry-after"] = String(describing: value)
            }
        }
        return ProviderHTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
    }
}
