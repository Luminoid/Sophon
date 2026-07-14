//
//  TestSupport.swift
//  SophonGeminiTests
//
//  Shared factories: isolated UserDefaults suites and configurations that never
//  touch the real Keychain or standard defaults.
//

import Foundation
import SophonGemini

enum TestSupport {
    /// A fresh, isolated UserDefaults suite so parallel tests never interfere.
    static func makeDefaults() -> UserDefaults {
        let name = "SophonGeminiTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Could not create UserDefaults suite \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func makeConfiguration(
        defaults: UserDefaults? = nil,
        defaultModel: GeminiModel = .gemini31FlashLite,
        fallbackModel: GeminiModel = .gemini31FlashLite,
        availableModels: [GeminiModel] = GeminiModel.allStandardCases,
        retryPolicy: GeminiRetryPolicy = .default
    ) -> GeminiClientConfiguration {
        GeminiClientConfiguration(
            keychainAccount: "com.sophon.tests.geminiAPIKey",
            defaults: defaults ?? makeDefaults(),
            defaultModel: defaultModel,
            fallbackModel: fallbackModel,
            availableModels: availableModels,
            retryPolicy: retryPolicy,
            logHandler: { _, _ in }
        )
    }

    static func makeHTTPResponse(status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        guard let url = URL(string: "https://example.com"),
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else {
            preconditionFailure("Could not build HTTPURLResponse")
        }
        return response
    }
}
