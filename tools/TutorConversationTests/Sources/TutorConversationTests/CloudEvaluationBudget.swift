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
    static let incidentUnknownHoldMicroUSD = 9_888_608
    static let canonicalURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/TrackSmith/Evaluations/package019-cloud-budget-v1.json")
    private let url: URL
    private let capMicroUSD: Int

    init(url: URL, capMicroUSD: Int, create: Bool = false, externalUnknownHoldMicroUSD: Int = 0) throws {
        guard capMicroUSD > 0 && capMicroUSD <= Self.maximumCapMicroUSD, externalUnknownHoldMicroUSD >= 0, externalUnknownHoldMicroUSD <= capMicroUSD else { throw CloudEvaluationBudgetError.invalid("cap or external unknown hold is outside bounds") }
        self.url = url; self.capMicroUSD = capMicroUSD
        try withLock {
            if fileExists(url) {
                let ledger = try read()
                guard ledger.cap == capMicroUSD else { throw CloudEvaluationBudgetError.invalid("ledger cap does not match explicit cap") }
                let holds = ledger.reservations.filter { ($0["state"] as? String) == "external_unknown_reserved" }
                guard holds.count <= 1, externalUnknownHoldMicroUSD == 0 || (exactInt(holds.first?["reserved_microusd"]) == externalUnknownHoldMicroUSD) else { throw CloudEvaluationBudgetError.invalid("existing external unknown hold cannot be replaced or lowered") }
            } else if create {
                let reservations: [[String: Any]] = externalUnknownHoldMicroUSD == 0 ? [] : [["id": "00000000-0000-0000-0000-000000000001", "state": "external_unknown_reserved", "reserved_microusd": externalUnknownHoldMicroUSD, "input_bound_tokens": 524_288, "output_bound_tokens": 25_000]]
                try write(.init(cap: capMicroUSD, spent: 0, reserved: externalUnknownHoldMicroUSD, poisoned: false, reservations: reservations))
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
        let canonical = canonicalURL.standardizedFileURL
        if let supplied = environment["CLOUD_BUDGET_LEDGER"], URL(fileURLWithPath: supplied).standardizedFileURL != canonical {
            throw CloudEvaluationBudgetError.invalid("CLOUD_BUDGET_LEDGER must equal the canonical Package 019 ledger path")
        }
        let rawHold = environment["CLOUD_BUDGET_EXTERNAL_UNKNOWN_HOLD_MICROUSD"]
        guard !create || rawHold == String(incidentUnknownHoldMicroUSD) else { throw CloudEvaluationBudgetError.invalid("first live initialization requires the exact incident unknown hold") }
        let hold = rawHold.flatMap(Int.init) ?? 0
        guard rawHold == nil || (rawHold?.range(of: "^[0-9]+$", options: .regularExpression) != nil && hold >= 0) else { throw CloudEvaluationBudgetError.invalid("external unknown hold must be a nonnegative exact integer") }
        try validateCanonicalParent(create: create)
        let ledger = try CloudEvaluationBudgetLedger(url: canonical, capMicroUSD: cap, create: create, externalUnknownHoldMicroUSD: create ? hold : 0)
        guard (try ledger.snapshotArtifact())["external_unknown_hold_microusd"] as? Int == incidentUnknownHoldMicroUSD else { throw CloudEvaluationBudgetError.invalid("live ledger is missing the immutable incident hold") }
        return ledger
    }

    func reserve(request: TutorStreamingHTTPRequest) throws -> CloudBudgetReservation {
        let plan = try pricingPlan(request)
        return try withLock {
            var ledger = try read()
            guard ledger.cap == capMicroUSD, !ledger.poisoned else { throw CloudEvaluationBudgetError.invalid("ledger accounting is invalid or poisoned") }
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

    /// Only a completed response with exact cache-classified usage and a
    /// documented tier may reduce a reservation. Any other outcome poisons the
    /// ledger so a missing/ambiguous cache classification cannot be reported as
    /// confirmed provider spend or permit a later request.
    func settle(_ reservation: CloudBudgetReservation, completedResponse: [String: Any]) throws {
        guard let model = completedResponse["model"] as? String, model == "gpt-5.6-sol",
              let tier = completedResponse["service_tier"] as? String, tier == "priority",
              let usage = exactUsage(completedResponse["usage"]) else { try poison(); return }
        let actual: Int
        do { actual = try cost(uncachedInput: usage.uncachedInput, cacheRead: usage.cacheRead, cacheWrite: usage.cacheWrite, output: usage.output, long: usage.input > 272_000, tier: tier) }
        catch { try poison(); return }
        guard actual <= reservation.microUSD else { try poison(); return }
        try withLock {
            var ledger = try read()
            guard let index = ledger.reservations.firstIndex(where: { ($0["id"] as? String) == reservation.id && ($0["state"] as? String) == "reserved" }) else { throw CloudEvaluationBudgetError.invalid("reservation is missing") }
            guard let reserved = ledger.reservations[index]["reserved_microusd"] as? Int, reserved == reservation.microUSD, ledger.reserved >= reserved else { throw CloudEvaluationBudgetError.invalid("reservation accounting is corrupt") }
            ledger.reserved -= reserved; ledger.spent += actual
            ledger.reservations[index]["state"] = "settled"
            ledger.reservations[index]["spent_microusd"] = actual
            try write(ledger)
        }
    }

    private struct Ledger {
        var cap: Int; var spent: Int; var reserved: Int; var poisoned: Bool; var reservations: [[String: Any]]
    }

    private func pricingPlan(_ request: TutorStreamingHTTPRequest) throws -> (microUSD: Int, inputBound: Int, outputBound: Int) {
        guard let object = try JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              object["model"] as? String == "gpt-5.6-sol", object["service_tier"] as? String == "priority",
              let output = object["max_output_tokens"] as? Int, output > 0 && output <= 5_000 else {
            throw CloudEvaluationBudgetError.invalid("unsupported model, tier, or maximum output pricing plan")
        }
        let input = request.body.count
        // Request bytes bound the input token count conservatively. Before the
        // response discloses cache classes, reserve every input unit at the
        // highest cache-write rate rather than assuming a cache hit.
        return (try cost(uncachedInput: 0, cacheRead: 0, cacheWrite: input, output: output, long: input > 272_000), input, output)
    }

    private struct ExactUsage {
        let input: Int; let uncachedInput: Int; let cacheRead: Int; let cacheWrite: Int; let output: Int
    }

    private func exactUsage(_ value: Any?) -> ExactUsage? {
        guard let usage = value as? [String: Any],
              let input = exactInt(usage["input_tokens"]), let output = exactInt(usage["output_tokens"]),
              let total = exactInt(usage["total_tokens"]),
              let details = usage["input_tokens_details"] as? [String: Any],
              Set(details.keys) == Set(["cached_tokens", "cache_creation_tokens"]),
              let cacheRead = exactInt(details["cached_tokens"]), let cacheWrite = exactInt(details["cache_creation_tokens"]),
              input >= 0, output >= 0, cacheRead >= 0, cacheWrite >= 0,
              cacheRead <= input, cacheWrite <= input - cacheRead else { return nil }
        let (sum, overflow) = input.addingReportingOverflow(output)
        guard !overflow else { return nil }
        guard total == sum else { return nil }
        let uncached = input - cacheRead - cacheWrite
        return .init(input: input, uncachedInput: uncached, cacheRead: cacheRead, cacheWrite: cacheWrite, output: output)
    }

    private func cost(uncachedInput: Int, cacheRead: Int, cacheWrite: Int, output: Int, long: Bool, tier: String = "priority") throws -> Int {
        guard uncachedInput >= 0 && cacheRead >= 0 && cacheWrite >= 0 && output >= 0 else { throw CloudEvaluationBudgetError.invalid("negative token accounting") }
        let rates: (uncached: Int, cacheRead: Int, cacheWrite: Int, output: Int)
        switch tier {
        // Cache reads are discounted; writes are reserved at the documented
        // worst input rate. Integer microUSD rounds the discounted read upward.
        case "priority": rates = long ? (16, 2, 16, 60) : (8, 1, 8, 40)
        default: throw CloudEvaluationBudgetError.invalid("unsupported completed service tier")
        }
        let terms = [(uncachedInput, rates.uncached), (cacheRead, rates.cacheRead), (cacheWrite, rates.cacheWrite), (output, rates.output)]
        var total = 0
        for (tokens, rate) in terms {
            let (cost, costOverflow) = tokens.multipliedReportingOverflow(by: rate)
            let (next, totalOverflow) = total.addingReportingOverflow(cost)
            guard !costOverflow && !totalOverflow else { throw CloudEvaluationBudgetError.invalid("cost overflow") }
            total = next
        }
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
              Set(object.keys) == Set(["schema_version", "pricing_source", "model", "tier", "cap_microusd", "spent_microusd", "reserved_microusd", "poisoned", "reservations"]),
              object["schema_version"] as? String == Self.schema, object["pricing_source"] as? String == Self.pricingSource,
              object["model"] as? String == "gpt-5.6-sol", object["tier"] as? String == "priority",
              let cap = exactInt(object["cap_microusd"]), let spent = exactInt(object["spent_microusd"]),
              let reserved = exactInt(object["reserved_microusd"]), let poisoned = object["poisoned"] as? Bool, let reservations = object["reservations"] as? [[String: Any]],
              cap > 0, cap <= Self.maximumCapMicroUSD, spent >= 0, reserved >= 0, spent <= cap, reserved <= cap - spent else {
            throw CloudEvaluationBudgetError.invalid("ledger is corrupt, nonregular, or has unsupported pricing")
        }
        var ids = Set<String>(), calculatedSpent = 0, calculatedReserved = 0
        for entry in reservations {
            guard let id = entry["id"] as? String, UUID(uuidString: id) != nil, ids.insert(id).inserted,
                  let state = entry["state"] as? String,
                  let reservedAmount = exactInt(entry["reserved_microusd"]), reservedAmount > 0, reservedAmount <= cap,
                  let inputBound = exactInt(entry["input_bound_tokens"]), inputBound >= 0,
                  let outputBound = exactInt(entry["output_bound_tokens"]), outputBound > 0 else {
                throw CloudEvaluationBudgetError.invalid("ledger reservation schema is corrupt")
            }
            switch state {
            case "reserved":
                guard Set(entry.keys) == Set(["id", "state", "reserved_microusd", "input_bound_tokens", "output_bound_tokens"]), outputBound <= 5_000 else { throw CloudEvaluationBudgetError.invalid("ledger reservation keys are corrupt") }
                let (next, overflow) = calculatedReserved.addingReportingOverflow(reservedAmount)
                guard !overflow && next <= cap else { throw CloudEvaluationBudgetError.invalid("ledger reserved total overflows") }
                calculatedReserved = next
            case "settled":
                guard Set(entry.keys) == Set(["id", "state", "reserved_microusd", "input_bound_tokens", "output_bound_tokens", "spent_microusd"]), outputBound <= 5_000, let settled = exactInt(entry["spent_microusd"]), settled >= 0, settled <= reservedAmount else { throw CloudEvaluationBudgetError.invalid("ledger settlement schema is corrupt") }
                let (next, overflow) = calculatedSpent.addingReportingOverflow(settled)
                guard !overflow && next <= cap else { throw CloudEvaluationBudgetError.invalid("ledger spent total overflows") }
                calculatedSpent = next
            case "external_unknown_reserved":
                guard Set(entry.keys) == Set(["id", "state", "reserved_microusd", "input_bound_tokens", "output_bound_tokens"]), id == "00000000-0000-0000-0000-000000000001", inputBound == 524_288, outputBound == 25_000 else { throw CloudEvaluationBudgetError.invalid("external unknown hold schema is corrupt") }
                let (next, overflow) = calculatedReserved.addingReportingOverflow(reservedAmount)
                guard !overflow && next <= cap else { throw CloudEvaluationBudgetError.invalid("ledger external hold total overflows") }
                calculatedReserved = next
            default: throw CloudEvaluationBudgetError.invalid("ledger reservation state is unsupported")
            }
        }
        guard calculatedSpent == spent && calculatedReserved == reserved else { throw CloudEvaluationBudgetError.invalid("ledger totals do not reconcile reservations") }
        return .init(cap: cap, spent: spent, reserved: reserved, poisoned: poisoned, reservations: reservations)
    }

    private func write(_ ledger: Ledger) throws {
        guard !fileExists(url) || isRegular(url) else { throw CloudEvaluationBudgetError.invalid("ledger is not a regular file") }
        let object: [String: Any] = ["schema_version": Self.schema, "pricing_source": Self.pricingSource, "model": "gpt-5.6-sol", "tier": "priority", "cap_microusd": ledger.cap, "spent_microusd": ledger.spent, "reserved_microusd": ledger.reserved, "poisoned": ledger.poisoned, "reservations": ledger.reservations]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: url, options: [.atomic])
        guard chmod(url.path, 0o600) == 0 else { throw CloudEvaluationBudgetError.invalid("ledger permissions cannot be restricted") }
    }

    private func withLock<T>(_ work: () throws -> T) throws -> T {
        let lock = URL(fileURLWithPath: url.path + ".lock")
        let descriptor = open(lock.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CloudEvaluationBudgetError.invalid("ledger lock is unavailable") }
        defer { close(descriptor) }
        guard fchmod(descriptor, 0o600) == 0 else { throw CloudEvaluationBudgetError.invalid("ledger lock permissions cannot be restricted") }
        var opened = stat(), named = stat()
        guard fstat(descriptor, &opened) == 0, lstat(lock.path, &named) == 0, (opened.st_mode & S_IFMT) == S_IFREG, opened.st_nlink == 1, opened.st_dev == named.st_dev, opened.st_ino == named.st_ino else { throw CloudEvaluationBudgetError.invalid("ledger lock identity is unsafe") }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CloudEvaluationBudgetError.invalid("ledger lock cannot be acquired") }
        defer { _ = flock(descriptor, LOCK_UN) }
        guard lstat(lock.path, &named) == 0, named.st_dev == opened.st_dev, named.st_ino == opened.st_ino, named.st_nlink == 1 else { throw CloudEvaluationBudgetError.invalid("ledger lock changed before work") }
        let result = try work()
        var current = stat()
        guard lstat(lock.path, &current) == 0, current.st_dev == opened.st_dev, current.st_ino == opened.st_ino, current.st_nlink == 1 else { throw CloudEvaluationBudgetError.invalid("ledger lock changed while held") }
        return result
    }

    private func fileExists(_ candidate: URL) -> Bool { FileManager.default.fileExists(atPath: candidate.path) }
    private func isRegular(_ candidate: URL) -> Bool {
        var status = stat()
        return lstat(candidate.path, &status) == 0 && (status.st_mode & S_IFMT) == S_IFREG && status.st_nlink == 1
    }

    private func exactInt(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        let number = value.intValue
        return NSNumber(value: number) == value ? number : nil
    }

    private static func validateCanonicalParent(create: Bool) throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let components = ["Library", "Application Support", "TrackSmith", "Evaluations"]
        var current = home
        for (index, component) in components.enumerated() {
            current.appendPathComponent(component, isDirectory: true)
            if !FileManager.default.fileExists(atPath: current.path) {
                guard create else { throw CloudEvaluationBudgetError.invalid("canonical ledger parent is missing") }
                try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false, attributes: index == components.count - 1 ? [.posixPermissions: 0o700] : [:])
            }
            var status = stat()
            guard lstat(current.path, &status) == 0, (status.st_mode & S_IFMT) == S_IFDIR else { throw CloudEvaluationBudgetError.invalid("canonical ledger parent contains a symlink or non-directory") }
            if index == components.count - 1 {
                guard status.st_uid == getuid(), chmod(current.path, 0o700) == 0 else { throw CloudEvaluationBudgetError.invalid("canonical ledger directory ownership or permissions are unsafe") }
            }
        }
    }

    func snapshotArtifact() throws -> [String: Any] {
        try withLock {
            let ledger = try read()
            let external = ledger.reservations.first(where: { ($0["state"] as? String) == "external_unknown_reserved" }).flatMap { exactInt($0["reserved_microusd"]) } ?? 0
            return ["schema_version": Self.schema, "pricing_source": Self.pricingSource, "cap_microusd": ledger.cap, "spent_microusd": ledger.spent, "reserved_microusd": ledger.reserved, "external_unknown_hold_microusd": external, "poisoned": ledger.poisoned, "reservation_count": ledger.reservations.count]
        }
    }

    private func poison() throws {
        try withLock { var ledger = try read(); ledger.poisoned = true; try write(ledger) }
    }

    /// A forwarded request whose stream did not yield a trustworthy completed
    /// response keeps its reservation and closes the ledger to later requests.
    /// This prevents a partial or malformed SSE stream from being mistaken for
    /// cache-classified spend while preserving the conservative reservation.
    func failClosed(_ reservation: CloudBudgetReservation) throws {
        try withLock {
            var ledger = try read()
            guard let index = ledger.reservations.firstIndex(where: {
                ($0["id"] as? String) == reservation.id && ($0["state"] as? String) == "reserved"
            }), let reserved = ledger.reservations[index]["reserved_microusd"] as? Int,
               reserved == reservation.microUSD else {
                throw CloudEvaluationBudgetError.invalid("unsettled reservation is missing")
            }
            ledger.poisoned = true
            try write(ledger)
        }
    }

    static func selfTest() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tracksmith-p19-budget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent("ledger.json")
        let ledger = try CloudEvaluationBudgetLedger(url: path, capMicroUSD: 300_000, create: true)
        let heldPath = root.appendingPathComponent("external-hold.json")
        let heldLedger = try CloudEvaluationBudgetLedger(url: heldPath, capMicroUSD: 300_000, create: true, externalUnknownHoldMicroUSD: 12_345)
        guard (try heldLedger.snapshotArtifact())["reserved_microusd"] as? Int == 12_345 else { throw CloudEvaluationBudgetError.invalid("external unknown hold was not retained") }
        do { _ = try CloudEvaluationBudgetLedger(url: heldPath, capMicroUSD: 300_000, externalUnknownHoldMicroUSD: 12_344); throw CloudEvaluationBudgetError.invalid("external unknown hold was lowered") }
        catch is CloudEvaluationBudgetError {}
        let counter = CloudBudgetCountingTransport()
        let guarded = CloudBudgetedTutorTransport(base: counter, ledger: ledger)
        let body = try JSONSerialization.data(withJSONObject: ["model": "gpt-5.6-sol", "service_tier": "priority", "max_output_tokens": 5_000], options: [.sortedKeys])
        let request = TutorStreamingHTTPRequest(url: OpenAITutorProvider.endpoint, headers: [:], body: body, timeoutSeconds: 1)
        let incomplete = try await guarded.stream(request)
        for try await _ in incomplete.lines {}
        guard (try ledger.snapshotArtifact())["poisoned"] as? Bool == true else {
            throw CloudEvaluationBudgetError.invalid("missing completed response did not close ledger")
        }
        do { _ = try await guarded.stream(request); throw CloudEvaluationBudgetError.invalid("cap test unexpectedly forwarded") }
        catch is CloudEvaluationBudgetError {}
        guard counter.count == 1 else { throw CloudEvaluationBudgetError.invalid("reservation over cap reached forwarding transport") }
        func cacheUsage(input: Int, output: Int, read: Int, write: Int) -> [String: Any] {
            var usage: [String: Any] = [
                "input_tokens": input,
                "output_tokens": output,
                "input_tokens_details": ["cached_tokens": read, "cache_creation_tokens": write],
            ]
            let (total, overflow) = input.addingReportingOverflow(output)
            if !overflow { usage["total_tokens"] = total }
            return usage
        }
        let settledLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("settled.json"), capMicroUSD: 300_000, create: true)
        let settled = try settledLedger.reserve(request: request)
        try settledLedger.settle(settled, completedResponse: ["model": "gpt-5.6-sol", "service_tier": "priority", "usage": cacheUsage(input: 1, output: 1, read: 0, write: 0)])
        let settledSnapshot = try settledLedger.snapshotArtifact()
        guard settledSnapshot["spent_microusd"] as? Int == 48, settledSnapshot["reserved_microusd"] as? Int == 0 else { throw CloudEvaluationBudgetError.invalid("priority settlement did not reduce reservation") }
        let cacheLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("cache.json"), capMicroUSD: 300_000, create: true)
        let cached = try cacheLedger.reserve(request: request)
        try cacheLedger.settle(cached, completedResponse: ["model": "gpt-5.6-sol", "service_tier": "priority", "usage": cacheUsage(input: 10, output: 1, read: 3, write: 2)])
        guard (try cacheLedger.snapshotArtifact())["spent_microusd"] as? Int == 99 else { throw CloudEvaluationBudgetError.invalid("cache-classified settlement did not use separate rates") }
        for (name, usage) in [
            ("missing", ["input_tokens": 1, "output_tokens": 1]),
            ("malformed", ["input_tokens": 1, "output_tokens": 1, "input_tokens_details": ["cached_tokens": 2, "cache_creation_tokens": 0]]),
        ] as [(String, [String: Any])] {
            let invalidLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("\(name).json"), capMicroUSD: 300_000, create: true)
            let invalidReservation = try invalidLedger.reserve(request: request)
            try invalidLedger.settle(invalidReservation, completedResponse: ["model": "gpt-5.6-sol", "service_tier": "priority", "usage": usage])
            let invalidSnapshot = try invalidLedger.snapshotArtifact()
            guard invalidSnapshot["poisoned"] as? Bool == true, invalidSnapshot["reserved_microusd"] as? Int == invalidReservation.microUSD else { throw CloudEvaluationBudgetError.invalid("\(name) cache usage released a reservation") }
        }
        let retained = try settledLedger.reserve(request: request)
        try settledLedger.settle(retained, completedResponse: ["model": "gpt-5.6-sol", "service_tier": "unsupported", "usage": cacheUsage(input: 1, output: 1, read: 0, write: 0)])
        guard (try settledLedger.snapshotArtifact())["reserved_microusd"] as? Int == retained.microUSD else { throw CloudEvaluationBudgetError.invalid("untrusted usage released reservation") }
        let poisonLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("poison.json"), capMicroUSD: 300_000, create: true)
        let poisonReservation = try poisonLedger.reserve(request: request)
        try poisonLedger.settle(poisonReservation, completedResponse: ["model": "gpt-5.6-sol", "service_tier": "priority", "usage": cacheUsage(input: 9_999_999, output: 9_999_999, read: 0, write: 0)])
        let poisonedCounter = CloudBudgetCountingTransport()
        do { _ = try await CloudBudgetedTutorTransport(base: poisonedCounter, ledger: poisonLedger).stream(request); throw CloudEvaluationBudgetError.invalid("poisoned ledger forwarded") }
        catch is CloudEvaluationBudgetError {}
        guard poisonedCounter.count == 0, (try poisonLedger.snapshotArtifact())["poisoned"] as? Bool == true else { throw CloudEvaluationBudgetError.invalid("poisoned ledger allowed a later forward") }
        let overflowLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("overflow.json"), capMicroUSD: 300_000, create: true)
        let overflowReservation = try overflowLedger.reserve(request: request)
        try overflowLedger.settle(overflowReservation, completedResponse: ["model": "gpt-5.6-sol", "service_tier": "priority", "usage": cacheUsage(input: Int.max, output: Int.max, read: 0, write: 0)])
        let overflowCounter = CloudBudgetCountingTransport()
        do { _ = try await CloudBudgetedTutorTransport(base: overflowCounter, ledger: overflowLedger).stream(request); throw CloudEvaluationBudgetError.invalid("overflow-poisoned ledger forwarded") }
        catch is CloudEvaluationBudgetError {}
        guard overflowCounter.count == 0 else { throw CloudEvaluationBudgetError.invalid("cost overflow allowed a later forward") }
        let concurrentLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("concurrent.json"), capMicroUSD: 300_000, create: true)
        let concurrentCounter = CloudBudgetCountingTransport()
        let concurrentGuard = CloudBudgetedTutorTransport(base: concurrentCounter, ledger: concurrentLedger)
        async let first = try? concurrentGuard.stream(request)
        async let second = try? concurrentGuard.stream(request)
        _ = await (first, second)
        guard concurrentCounter.count == 1 else { throw CloudEvaluationBudgetError.invalid("concurrent reservation over cap reached forwarding transport") }
        _ = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("mismatch.json"), capMicroUSD: 300_000, create: true)
        do { _ = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("mismatch.json"), capMicroUSD: 300_001); throw CloudEvaluationBudgetError.invalid("mismatched cap accepted") }
        catch is CloudEvaluationBudgetError {}
        let link = root.appendingPathComponent("link.json")
        guard symlink(path.path, link.path) == 0 else { throw CloudEvaluationBudgetError.invalid("symlink fixture unavailable") }
        do { _ = try CloudEvaluationBudgetLedger(url: link, capMicroUSD: 300_000); throw CloudEvaluationBudgetError.invalid("symlink ledger accepted") }
        catch is CloudEvaluationBudgetError {}
        let hard = root.appendingPathComponent("hard.json")
        guard Darwin.link(path.path, hard.path) == 0 else { throw CloudEvaluationBudgetError.invalid("hardlink fixture unavailable") }
        do { _ = try CloudEvaluationBudgetLedger(url: hard, capMicroUSD: 300_000); throw CloudEvaluationBudgetError.invalid("hardlinked ledger accepted") }
        catch is CloudEvaluationBudgetError {}
        let lockLedger = try CloudEvaluationBudgetLedger(url: root.appendingPathComponent("lock-ledger.json"), capMicroUSD: 300_000, create: true)
        let lockPath = root.appendingPathComponent("lock-ledger.json.lock")
        let lockHard = root.appendingPathComponent("lock-hard")
        guard Darwin.link(lockPath.path, lockHard.path) == 0 else { throw CloudEvaluationBudgetError.invalid("hardlinked lock fixture unavailable") }
        do { _ = try lockLedger.snapshotArtifact(); throw CloudEvaluationBudgetError.invalid("hardlinked lock accepted") }
        catch is CloudEvaluationBudgetError {}
        let entry: [String: Any] = ["id": "00000000-0000-0000-0000-000000000002", "state": "reserved", "reserved_microusd": 100, "input_bound_tokens": 1, "output_bound_tokens": 1]
        let valid: [String: Any] = ["schema_version": Self.schema, "pricing_source": Self.pricingSource, "model": "gpt-5.6-sol", "tier": "priority", "cap_microusd": 300_000, "spent_microusd": 0, "reserved_microusd": 100, "poisoned": false, "reservations": [entry]]
        var corruptions: [(String, [String: Any])] = []
        var boolean = valid; boolean["cap_microusd"] = true; corruptions.append(("bool", boolean))
        var fraction = valid; fraction["cap_microusd"] = 300_000.5; corruptions.append(("fraction", fraction))
        var duplicate = valid; duplicate["reservations"] = [entry, entry]; duplicate["reserved_microusd"] = 200; corruptions.append(("duplicate", duplicate))
        var mismatch = valid; mismatch["reserved_microusd"] = 99; corruptions.append(("mismatch", mismatch))
        for (name, object) in corruptions {
            let corrupt = root.appendingPathComponent("\(name).json")
            try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: corrupt)
            do { _ = try CloudEvaluationBudgetLedger(url: corrupt, capMicroUSD: 300_000); throw CloudEvaluationBudgetError.invalid("\(name) corrupt ledger accepted") }
            catch is CloudEvaluationBudgetError {}
        }
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
        let response: TutorStreamingHTTPResponse
        do {
            response = try await base.stream(request)
        } catch {
            try? ledger.failClosed(reservation)
            throw error
        }
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
                    guard let completed else {
                        try ledger.failClosed(reservation)
                        continuation.finish()
                        return
                    }
                    try ledger.settle(reservation, completedResponse: completed)
                    continuation.finish()
                } catch {
                    try? ledger.failClosed(reservation)
                    continuation.finish(throwing: error)
                }
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
