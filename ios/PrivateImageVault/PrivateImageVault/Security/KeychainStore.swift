import Foundation
import Security

/// Errors produced by the small Keychain wrapper.
enum KeychainStoreError: LocalizedError {
    /// The Security framework returned an unexpected OSStatus code.
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

/// Minimal Keychain wrapper for storing the API session token.
///
/// Session tokens should not live in `UserDefaults`. Keychain gives us a system
/// protected place for small secrets such as bearer tokens.
final class KeychainStore {
    /// Keychain service namespace for this app.
    private let service: String

    /// Creates a store scoped to the app's bundle identifier.
    init(service: String = Bundle.main.bundleIdentifier ?? "PrivateImageVault") {
        self.service = service
    }

    /// Saves data for a Keychain account name.
    func save(_ data: Data, account: String) throws {
        /// Delete first so the add operation works for both new and existing values.
        try delete(account: account)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    /// Reads data for a Keychain account name.
    func readData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }

        return result as? Data
    }

    /// Deletes data for a Keychain account name.
    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }

        throw KeychainStoreError.unhandledStatus(status)
    }

    /// Creates the common Keychain query fields used by save/read/delete.
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
