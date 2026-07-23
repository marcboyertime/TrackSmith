import Foundation
import Security

public enum ProviderCredentialIdentifier: String, Codable, CaseIterable, Sendable {
    case openAI
    case gemini

    public var keychainAccount: String { rawValue }
}

public enum ProviderCredentialError: Error, Equatable, Sendable {
    case invalidCredential
    case keychainFailure(operation: String, status: Int32)
}

public protocol ProviderCredentialStore: Sendable {
    func credential(for identifier: ProviderCredentialIdentifier) throws -> String?
    func saveCredential(_ credential: String, for identifier: ProviderCredentialIdentifier) throws
    func deleteCredential(for identifier: ProviderCredentialIdentifier) throws
}

/// Companion-only Keychain storage. Credentials are never written to App Group
/// state and therefore are not visible to the Audio Unit extension.
public struct KeychainProviderCredentialStore: ProviderCredentialStore, Sendable {
    public static let defaultService = "com.marcboyer.tracksmith.provider-credentials"
    public var service: String

    public init(service: String = Self.defaultService) {
        self.service = service
    }

    public func credential(for identifier: ProviderCredentialIdentifier) throws -> String? {
        let query: [CFString: Any] = baseQuery(identifier).merging([
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw ProviderCredentialError.keychainFailure(operation: "read", status: status)
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            throw ProviderCredentialError.invalidCredential
        }
        return value
    }

    public func saveCredential(
        _ credential: String,
        for identifier: ProviderCredentialIdentifier
    ) throws {
        let value = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count >= 8, value.utf8.count <= 8_192 else {
            throw ProviderCredentialError.invalidCredential
        }
        let data = Data(value.utf8)
        let query = baseQuery(identifier)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [
                kSecValueData: data,
                // Tighten an existing development item as well as new ones.
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw ProviderCredentialError.keychainFailure(operation: "update", status: updateStatus)
        }
        let add = query.merging([
            kSecValueData: data,
            // Cloud credentials are needed only while the signed companion is
            // in an interactive, unlocked user session. They never need the
            // broader post-first-unlock availability used by background agents.
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]) { _, new in new }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ProviderCredentialError.keychainFailure(operation: "save", status: addStatus)
        }
    }

    public func deleteCredential(for identifier: ProviderCredentialIdentifier) throws {
        let status = SecItemDelete(baseQuery(identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderCredentialError.keychainFailure(operation: "delete", status: status)
        }
    }

    private func baseQuery(_ identifier: ProviderCredentialIdentifier) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: identifier.keychainAccount,
            kSecAttrSynchronizable: false,
        ]
    }
}

/// Test and dependency-injection store. Production UI constructs the Keychain
/// implementation explicitly; it never falls back to environment variables.
public final class InMemoryProviderCredentialStore: ProviderCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ProviderCredentialIdentifier: String]

    public init(values: [ProviderCredentialIdentifier: String] = [:]) {
        self.values = values
    }

    public func credential(for identifier: ProviderCredentialIdentifier) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[identifier]
    }

    public func saveCredential(_ credential: String, for identifier: ProviderCredentialIdentifier) throws {
        let value = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count >= 8, value.utf8.count <= 8_192 else {
            throw ProviderCredentialError.invalidCredential
        }
        lock.lock()
        values[identifier] = value
        lock.unlock()
    }

    public func deleteCredential(for identifier: ProviderCredentialIdentifier) throws {
        lock.lock()
        values.removeValue(forKey: identifier)
        lock.unlock()
    }
}
