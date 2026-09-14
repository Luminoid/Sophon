//
//  ExampleConfigurations.swift
//  SophonExample
//
//  The example app's Sophon wiring for the providers with their own wire
//  protocol: one configuration and one shared client each. Real apps do
//  exactly this for the providers they ship, with their own Keychain accounts,
//  model catalogs, retry policies, and log handlers. The OpenAI-compatible
//  clients are built in ExampleProviders.
//

import SophonAnthropic
import SophonGemini

// MARK: - Gemini

extension GeminiClientConfiguration {
    /// Everything but the Keychain account is a package default: Sophon's
    /// recommended default and fallback models, every current preset,
    /// `.default` retry policy, `ai.*` UserDefaults keys, `os.Logger` logging.
    static let example = GeminiClientConfiguration(keychainAccount: "dev.luminoid.sophon.example.geminiAPIKey")
}

extension GeminiAPIClient {
    static let shared = GeminiAPIClient(configuration: .example)
}

// MARK: - Anthropic

extension AnthropicClientConfiguration {
    static let example = AnthropicClientConfiguration(keychainAccount: "dev.luminoid.sophon.example.anthropicAPIKey")
}

extension AnthropicAPIClient {
    static let shared = AnthropicAPIClient(configuration: .example)
}
