//
//  ExampleClient.swift
//  SophonExample
//
//  The example app's Sophon wiring: one configuration, one shared client.
//  Real apps do exactly this, with their own Keychain account, model catalog,
//  retry policy, and log handler.
//

import SophonGemini

extension GeminiClientConfiguration {
    /// Everything but the Keychain account is a package default: full model
    /// catalog, `.default` retry policy, `ai.*` UserDefaults keys, `os.Logger`
    /// logging under the `dev.luminoid.sophon` subsystem.
    static let example = GeminiClientConfiguration(
        keychainAccount: "dev.luminoid.sophon.example.geminiAPIKey"
    )
}

extension GeminiAPIClient {
    static let shared = GeminiAPIClient(configuration: .example)
}
