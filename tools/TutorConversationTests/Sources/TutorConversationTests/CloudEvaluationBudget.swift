import Darwin
import Foundation
import TutorConversation

/// Test-harness-only cumulative spend guard. It persists counts and monetary
/// reservations only; request bodies, credentials, provider prose, and labels
/// never enter the ledger.
enum CloudEvaluationBudgetError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { "cloud budget guard: \(message)" }
    private var message: String { if case let .invalid(value) = self { value } else { "invalid" } }
}

struct CloudBudgetReservation {
    let id: String
    let microUSD: Int
}

final class CloudEvaluationBudgetLedger: @unchecked Sendable {
    static let schema = "tracksmith-cloud-evaluation-budget/v1"
    static let pricingSource = "openai-gpt-5.6-sol-fast-2026-08-25"
    static let maximumCapMicroUSD = 50_000_000
    private let url: URL
    private let capMicroUSD: Int

    init(url: URL, capMicroUSD: Int, create: Bool = false) throws {
        guard capMicroUSD > 0 && capMicroUSD <= Self.maximumCapMicroUSD else { throw CloudEvaluationBudgetError.invalid("cap is outside 0...50 USD") }
        self.url = url; self.capMicroUSD = capMicroUSD
        try withLock {
            if fileExists(url) {
                let ledger = try read()
                guard ledger.cap == capMicroUSD else { throw CloudEvaluationBudgetError.invalid("ledger cap does not match explicit cap") }
            } else if create {
                try write(.init(cap: capMicroUSD, spent: 0, reserved: 0, reservations: []))
            } else {
                throw CloudEvaluationBudgetError.invalid("ledger is missing")
            }
        }
    }

    static func fromEnvironment(create: Bool = false) throws -> CloudEvaluationBudgetLedger {
        let environment = ProcessInfo.processInfo.environment
        guard let rawCap = environment["CLOUD_BUDGET_CAP_USD"], let cap = parseUSD(rawCap), cap == maximumCapMicroUSD else {
            throw CloudEvaluationBudgetError.invalid("CLOUD_BUDGET_CAP_USD must be exactly 50")
        }
        guard let path = environment["CLOUD_BUDGET_LEDGER"], !path.isEmpty else { throw CloudEvaluationBudgetError.invalid("CLOUD_BUDGET_LEDGER is required") }
        return try .init(url: URL(fileURLWithPath: path), capMicroUSD: cap, create: create)
    }

    func reserve(request: TutorStreamingHTTPRequest) throws -> CloudBudgetReservation {
        let plan = try pricingPlan(request)
        return try withLock {
            var ledger = try read()
            guard ledger.spent >= 0 && ledger.reserved >= 0 && ledger.cap == capMicroUSD else { throw CloudEvaluationBudgetError.invalid("ledger accounting is invalid") }
            guard ledger.spent <= ledger.cap, ledger.reserved <= ledger.cap - ledger.spent, plan.microUSD <= ledger.cap - ledger.spent - ledger.reserved else {
                throw CloudEvaluationBudgetError.invalid("conservative reservation exceeds remaining cumulative cap")
            }
            let reservation = CloudBudgetReservation(id: UUID().uuidString.lowercased(), microUSD: plan.microUSD)
            ledger.reserved += plan.microUSD
            ledger.reservations.append(["id": reservation.id, "state": "reserved", "reserved_microusd": plan.microUSD, "input_bound_tokens": plan.inputBound, "output_bound_tokens": plan.outputBound])
            try write(ledger)
            return reservation
        }
    }

    /// Only a completed response that reports the pinned tier and finite exact
    /// usage may reduce a reservation. Any other outcome deliberately keeps it.
    func settle(_ reservation: CloudBudgetReservation, completedResponse: [String: Any]) throws {
        guard let model = completedResponse["model"] as? String, model == "gpt-5.6-sol",
              let tier = completedResponse["service_tier"] as? String, tier == "priority",
              let usage = completedResponse["usage"] as? [String: Any],
              let input = usage["input_tokens"] as? Int, let output = usage["output_tokens"] as? Int,
              input >= 0, output >= 0 else { return }
        let long = input > 272_000
        let actual = try cost(input: input, output: output, long: long)
        guard actual <= reservation.microUSD else { return }
        try withLock {
            var ledger = try read()
            guard let index = ledger.reservations.firstIndex(where: { ($0["id"] as? String) == reservation.id && ($0["state"] as? String) == "reserved" }) else { throw CloudEvaluationBudgetError.invalid("reservation is missing") }
            guard let reserved = ledger.reservations[index]["reserved_microusd"] as? Int, reserved == reservation.microUSD, ledger.reserved >= reserved else { throw CloudEvaluationBudgetError.invalid("reservation accounting is corrupt") }
            ledger.reserved -= reserved; ledger.spent += actual
            ledger.reservations[index] = ["id": reservation.id, "state": "settled", "reserved_microusd": reserved, "spent_microusd": actual]
            try write(ledger)
        }
    }

    private struct Ledger {
        var cap: Int; var spent: Int; var reserved: Int; var reservations: [[String: Any]]
    }

    private func pricingPlan(_ request: TutorStreamingHTTPRequest) throws -> (microUSD: Int, inputBound: Int, outputBound: Int) {
        guard let object = try JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              object["model"] as? String == "gpt-5.6-sol", object["service_tier"] as? String == "priority",
              let output = object["max_output_tokens"] as? Int, output > 0 && output <= 5_000 else {
            throw CloudEvaluationBudgetError.invalid("unsupported model, tier, or maximum output pricing plan")
        }
        let input = request.body.count
        return (try cost(input: input, output: output, long: input > 272_000), input, output)
    }

    private func cost(input: Int, output: Int, long: Bool) throws -> Int {
        guard input >= 0 && output >= 0 else { throw CloudEvaluationBudgetError.invalid("negative token accounting") }
        let inputRate = long ? 16 : 8 // micro-USD/token; priority Fast pricing.
        let outputRate = long ? 60 : 40
        let (inputCost, inputOverflow) = input.multipliedReportingOverflow(by: inputRate)
        let (outputCost, outputOverflow) = output.multipliedReportingOverflow(by: outputRate)
        let (total, totalOverflow) = inputCost.addingReportingOverflow(outputCost)
        guard !inputOverflow && !outputOverflow && !totalOverflow else { throw CloudEvaluationBudgetError.invalid("cost overflow") }
        return total
    }

    private static func parseUSD(_ value: String) -> Int? {
        guard value.range(of: "^[0-9]+(?:\\.[0-9]{1,6})?$", options: .regularExpression) != nil else { return nil }
        let parts = value.split(separator: ".", maxSplits: 1).map(String.init)
        guard let whole = Int(parts[0]), whole >= 0 else { return nil }
        let fraction = parts.count == 2 ? parts[1] : ""
        let padded = fraction + String(repeating: "0", count: 6 - fraction.count)
        guard let micro = Int(padded), whole <= (Int.max - micro) / 1_000_000 else { return nil }
        return whole * 1_000_000 + micro
    }

    private func read() throws -> Ledger {
        guard isRegular(url), let data = try? Data(contentsOf: url), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["schema_version", "pricing_source", "model", "tier", "cap_microusd", "spent_microusd", "reserved_microusd", "reservations"]),
              object["schema_version"] as? String == Self.schema, object["pricing_source"] as? String == Self.pricingSource,
              object["model"] as? String == "gpt-5.6-sol", object["tier"] as? String == "priority",
              let cap = object["cap_microusd"] as? Int, let spent = object["spent_microusd"] as? Int,
              let reserved = object["reserved_microusd"] as? Int, let reservations = object["reservations"] as? [[String: Any]] else {
            throw CloudEvaluationBudgetError.invalid("ledger is corrupt, nonregular, or has unsupported pricing")
        }
        return .init(cap: cap, spent: spent, reserved: reserved, reservations: reservations)
    }

    private func write(_ ledger: Ledger) throws {
        guard !fileExists(url) || isRegular(url) else { throw CloudEvaluationBudgetError.invalid("ledger is not a regular file") }
        let object: [String: Any] = ["schema_version": Self.schema, "pricing_source": Self.pricingSource, "model": "gpt-5.6-sol", "tier": "priority", "cap_microusd": ledger.cap, "spent_microusd": ledger.spent, "reserved_microusd": ledger.reserved, "reservations": ledger.reservations]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: url, options: [.atomic])
    }

    private func withLock<T>(_ work: () throws -> T) throws -> T {
        let lock = URL(fileURLWithPath: url.path + ".lock")
        let descriptor = open(lock.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CloudEvaluationBudgetError.invalid("ledger lock is unavailable") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CloudEvaluationBudgetError.invalid("ledger lock cannot be acquired") }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try work()
    }

    private func fileExists(_ candidate: URL) -> Bool { FileManager.default.fileExists(atPath: candidate.path) }
    private func isRegular(_ candidate: URL) -> Bool {
        var status = stat()
        return lstat(candidate.path, &status) == 0 && (status.st_mode & S_IFMT) == S_IFREG
    }

    static func selfTest() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tracksmith-p19-budget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent("ledger.json")
        let ledger = try CloudEvaluationBudgetLedger(url: path, capMicroUSD: 300_000, create: true)
        let counter = CloudBudgetCountingTransport()
        let guarded = CloudBudgetedTutorTransport(base: counter, ledger: ledger)
        let body = try JSONSerialization.data(withJSONObject: ["model": "gpt-5.6-sol", "service_tier": "priority", "max_output_tokens": 5_000], options: [.sortedKeys])
        let request = TutorStreamingHTTPRequest(url: OpenAITutorProvider.endpoint, headers: [:], body: body, timeoutSeconds: 1)
        _ = try await guarded.stream(request)
        do { _ = try await guarded.stream(request); throw CloudEvaluationBudgetError.invalid("cap test unexpectedly forwarded") }
        catch is CloudEvaluationBudgetError {}
        guard counter.count == 1 else { throw CloudEvaluationBudgetError.invalid("reservation over cap reached forwarding transport") }
        _ = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("mismatch.json"), capMicroUSD: 300_000, create: true)
        do { _ = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("mismatch.json"), capMicroUSD: 300_001); throw CloudEvaluationBudgetError.invalid("mismatched cap accepted") }
        catch is CloudEvaluationBudgetError {}
        let link = root.appendingPathComponent("link.json")
        guard symlink(path.path, link.path) == 0 else { throw CloudEvaluationBudgetError.invalid("symlink fixture unavailable") }
        do { _ = try CloudEvaluationBudgetLedger(url: link, capMicroUSD: 300_000); throw CloudEvaluationBudgetError.invalid("symlink ledger accepted") }
        catch is CloudEvaluationBudgetError {}
        try "not-json".data(using: .utf8)!.write(to: path, options: .atomic)
        do { _ = try CloudEvaluationBudgetLedger(url: path, capMicroUSD: 300_000); throw CloudEvaluationBudgetError.invalid("corrupt ledger accepted") }
        catch is CloudEvaluationBudgetError {}
    }
}

final class CloudBudgetedTutorTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let base: any TutorStreamingHTTPTransport
    private let ledger: CloudEvaluationBudgetLedger
    init(base: any TutorStreamingHTTPTransport = URLSessionTutorStreamingTransport(), ledger: CloudEvaluationBudgetLedger) { self.base = base; self.ledger = ledger }

    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        let reservation = try ledger.reserve(request: request)
        let response = try await base.stream(request)
        let wrapped = AsyncThrowingStream<String, Error> { continuation in
            Task {
                var completed: [String: Any]?
                do {
                    for try await line in response.lines {
                        if line.hasPrefix("data:"), let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces).data(using: .utf8),
                           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["type"] as? String == "response.completed" {
                            completed = object["response"] as? [String: Any]
                        }
                        continuation.yield(line)
                    }
                    if let completed { try ledger.settle(reservation, completedResponse: completed) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
        return .init(statusCode: response.statusCode, headers: response.headers, lines: wrapped)
    }
}

private final class CloudBudgetCountingTransport: TutorStreamingHTTPTransport, @unchecked Sendable {
    private let lock = NSLock(); private var requests = 0
    var count: Int { lock.withLock { requests } }
    func stream(_ request: TutorStreamingHTTPRequest) async throws -> TutorStreamingHTTPResponse {
        lock.withLock { requests += 1 }
        return .init(statusCode: 200, lines: AsyncThrowingStream { continuation in continuation.finish() })
    }
}
