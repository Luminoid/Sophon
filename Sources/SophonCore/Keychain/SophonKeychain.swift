//
//  SophonKeychain.swift
//  SophonCore
//
//  Minimal Keychain wrapper for securely storing API keys. The account string
//  is caller-supplied so each app keeps its existing Keychain item.
//
//  Items are keyed by account only (no kSecAttrService): the consuming apps'
//  pre-package items were stored that way, and adding a service attribute would
//  orphan them. Keep account strings reverse-DNS unique per app. Reads and
//  deletes match both synchronizable and local items, so a key an app once
//  stored in iCloud Keychain is still found and can still be removed; new items
//  are always local (`WhenUnlockedThisDeviceOnly`).
//

import Foundation
import Security

public enum SophonKeychain {
    // MARK: - Public API

    /// Store `value` under `account`, updating an existing item in place (no
    /// delete-then-add window in which a crash could lose the key).
    public static func save(account: String, value: String) throws {
        let data = Data(value.utf8)
        guard !data.isEmpty else { throw KeychainError.emptyValue }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var status = SecItemUpdate(matchQuery(account: account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
            ]
            addQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// The stored value, or nil when no item exists. Throws
    /// `KeychainError.loadFailed` when the Keychain refused the read (for
    /// example `errSecInteractionNotAllowed` on a locked device).
    public static func read(account: String) throws -> String? {
        var query = matchQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status)
        }
    }

    /// `read(account:)` with read failures folded into nil.
    public static func load(account: String) -> String? {
        (try? read(account: account)) ?? nil
    }

    /// Remove the item. Returns true when it is gone (removed or never there),
    /// false when the Keychain refused the delete.
    @discardableResult
    public static func delete(account: String) -> Bool {
        let status = SecItemDelete(matchQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Helpers

    /// Matches the account's item whether or not it is synchronizable.
    private static func matchQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }

    // MARK: - Errors

    public enum KeychainError: LocalizedError {
        /// Nothing to store after trimming.
        case emptyValue
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .emptyValue:
                "The API key is empty."
            case let .saveFailed(status):
                "Failed to save to Keychain (status: \(status))"
            case let .loadFailed(status):
                "Failed to read from Keychain (status: \(status))"
            }
        }
    }
}
