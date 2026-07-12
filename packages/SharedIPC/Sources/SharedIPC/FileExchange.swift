import Foundation
import PlanSchema

public enum ExchangeMessageKind: String, Codable, Sendable { case pluginHeartbeat, companionRequest, planProposal, acknowledgement }

public struct ExchangeMessage: Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: ExchangeMessageKind
    public var instanceID: UUID
    public var timestamp: Date
    public var text: String?
    public var plan: ProcessingPlan?

    public init(id: UUID = UUID(), kind: ExchangeMessageKind, instanceID: UUID, timestamp: Date = Date(), text: String? = nil, plan: ProcessingPlan? = nil) {
        self.id = id; self.kind = kind; self.instanceID = instanceID; self.timestamp = timestamp; self.text = text; self.plan = plan
    }
}

public enum ExchangeError: Error, Sendable { case invalidDirectory, messageNotFound(UUID) }

/// Prototype transport. Production builds place this exchange inside a signed App Group container.
public struct FileExchange: Sendable {
    public let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @discardableResult
    public func send(_ message: ExchangeMessage) throws -> URL {
        let destination = directory.appendingPathComponent(message.id.uuidString).appendingPathExtension("json")
        let temporary = directory.appendingPathComponent(".\(message.id.uuidString).tmp")
        try encoder.encode(message).write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    public func receive(id: UUID) throws -> ExchangeMessage {
        let url = directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw ExchangeError.messageNotFound(id) }
        return try decoder.decode(ExchangeMessage.self, from: Data(contentsOf: url))
    }

    public func list() throws -> [ExchangeMessage] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(ExchangeMessage.self, from: Data(contentsOf: $0)) }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
