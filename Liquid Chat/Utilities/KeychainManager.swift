//
//  KeychainManager.swift
//  Liquid Chat
//
//  Secure storage for IRC server passwords using the macOS Keychain.
//

import Foundation
import Security

enum KeychainManager {
    private static let service = "com.liquidchat.irc"

    /// Store (or update) a password for a server config ID.
    static func savePassword(_ password: String, for id: UUID) {
        let account = id.uuidString
        let data = Data(password.utf8)

        // Try update first
        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let updateAttrs: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)

        if status == errSecItemNotFound {
            // Not present yet — add new entry
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Retrieve a password for a server config ID. Returns nil if not found.
    static func loadPassword(for id: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a stored password for a server config ID.
    static func deletePassword(for id: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Client Identities (SASL EXTERNAL)

    /// Labels of client identities (certificate + private key pairs) available
    /// in the keychain, for the SASL EXTERNAL certificate picker.
    static func availableIdentityNames() -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let items = result as? [[CFString: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrLabel] as? String }.sorted()
    }

    /// Look up a client identity by its keychain label.
    static func findIdentity(named name: String) -> SecIdentity? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecAttrLabel: name,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnRef: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let ref = result,
              CFGetTypeID(ref) == SecIdentityGetTypeID() else { return nil }
        return (ref as! SecIdentity)
    }
}
