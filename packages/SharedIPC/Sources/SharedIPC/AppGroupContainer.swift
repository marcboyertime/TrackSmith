import Foundation

public enum AppGroupContainer {
    /// macOS direct-distribution app groups use the development-team prefix.
    /// This lets the system authorize both signed targets without a per-process
    /// App Data consent prompt.
    public static let identifier = "KDV9RC892F.com.marcboyer.logicaudioassistant"

    public static func exchangeRoot(fileManager: FileManager = .default) throws -> URL {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else { throw ExchangeError.appGroupUnavailable(identifier) }
        return container
            .appendingPathComponent("LogicAudioAssistant", isDirectory: true)
            .appendingPathComponent("Exchange-v1", isDirectory: true)
    }
}
