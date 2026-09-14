//
//  LLMProviderConfiguration.swift
//  SophonCore
//
//  The per-app knobs every provider configuration shares (Keychain account,
//  enabled toggle, defaults suite), plus the availability and API-key surface
//  built on them, written once for all providers.
//

import Foundation

public protocol LLMProviderConfiguration {
    /// Keychain account the API key is stored under (e.g. "com.example.<provider>APIKey").
    /// Apps migrating from a hand-rolled client must keep their existing value
    /// so users' saved keys survive.
    var keychainAccount: String { get }
    /// UserDefaults key of the user's feature toggle.
    var enabledDefaultsKey: String { get }
    var defaults: UserDefaults { get }
}

/// What a Keychain read of the API key found.
public enum LLMAPIKeyStatus: Sendable, Equatable {
    case stored(String)
    /// Nothing stored (or an empty value).
    case missing
    /// The Keychain refused the read, typically `errSecInteractionNotAllowed`
    /// while the device is locked; the key may well be stored.
    case inaccessible(OSStatus)
}

public extension LLMProviderConfiguration {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isAvailable: Bool {
        isEnabled && hasAPIKey
    }

    /// Whether an API key has been stored, independent of the enabled toggle.
    var hasAPIKey: Bool {
        loadAPIKey() != nil
    }

    /// Whether the user has switched the feature toggle on.
    var isEnabled: Bool {
        defaults.bool(forKey: enabledDefaultsKey)
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: enabledDefaultsKey)
    }

    /// The stored API key, or nil when absent, empty, or unreadable. Use
    /// `apiKeyStatus()` to tell a missing key from a locked Keychain.
    func loadAPIKey() -> String? {
        if case let .stored(apiKey) = apiKeyStatus() { return apiKey }
        return nil
    }

    /// The stored key, or why there is none.
    func apiKeyStatus() -> LLMAPIKeyStatus {
        do {
            guard let apiKey = try SophonKeychain.read(account: keychainAccount), !apiKey.isEmpty else {
                return .missing
            }
            return .stored(apiKey)
        } catch let SophonKeychain.KeychainError.loadFailed(status) {
            return .inaccessible(status)
        } catch {
            return .missing
        }
    }

    /// The stored key, throwing the caller's error for a missing or unreadable one.
    func requireAPIKey<Failure: Error>(missing: () -> Failure, inaccessible: (OSStatus) -> Failure) throws -> String {
        switch apiKeyStatus() {
        case let .stored(apiKey): apiKey
        case .missing: throw missing()
        case let .inaccessible(status): throw inaccessible(status)
        }
    }

    /// Store the key, trimmed of surrounding whitespace and newlines (a pasted
    /// key often carries one). Throws `SophonKeychain.KeychainError.emptyValue`
    /// when nothing is left.
    func saveAPIKey(_ value: String) throws {
        try SophonKeychain.save(account: keychainAccount, value: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func deleteAPIKey() {
        SophonKeychain.delete(account: keychainAccount)
    }

    /// Masked display form of the stored key: four bullets plus its last 4
    /// characters ("••••cD3f"). Keys of 8 characters or fewer render as bullets
    /// only, so the suffix never gives away most of a short key; nil when no
    /// key is stored.
    var maskedAPIKeyDisplay: String? {
        guard let key = loadAPIKey() else { return nil }
        let dots = String(repeating: "\u{2022}", count: 4)
        guard key.count > 8 else { return dots }
        return dots + key.suffix(4)
    }
}
