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
    /// Keychain account the API key is stored under (e.g. "com.example.geminiAPIKey").
    /// Apps migrating from a hand-rolled client must keep their existing value
    /// so users' saved keys survive.
    var keychainAccount: String { get }
    /// UserDefaults key of the user's feature toggle.
    var enabledDefaultsKey: String { get }
    var defaults: UserDefaults { get }
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

    /// The stored API key, or nil when absent/empty.
    func loadAPIKey() -> String? {
        guard let apiKey = SophonKeychain.load(account: keychainAccount), !apiKey.isEmpty else {
            return nil
        }
        return apiKey
    }

    func saveAPIKey(_ value: String) throws {
        try SophonKeychain.save(account: keychainAccount, value: value)
    }

    func deleteAPIKey() {
        SophonKeychain.delete(account: keychainAccount)
    }

    /// Masked display form of the stored key: four bullets plus its last 4
    /// characters ("••••cD3f"). Keys shorter than 4 characters render as bullets
    /// only; nil when no key is stored.
    var maskedAPIKeyDisplay: String? {
        guard let key = loadAPIKey() else { return nil }
        let dots = String(repeating: "\u{2022}", count: 4)
        guard key.count >= 4 else { return dots }
        return dots + key.suffix(4)
    }
}
