//
//  TestSupport.swift
//  SophonGeminiTests
//
//  The Gemini-specific configuration factory; isolated defaults and canned
//  responses come from the shared `SophonTestSupport` target.
//

import Foundation
import SophonGemini
import SophonTestSupport

enum TestSupport {
    static func makeConfiguration(
        defaults: UserDefaults? = nil,
        defaultModel: GeminiModel = .gemini31FlashLite,
        fallbackModel: GeminiModel = .gemini31FlashLite,
        availableModels: [GeminiModel] = GeminiModel.allStandardCases,
        apiBaseURL: String = "https://generativelanguage.googleapis.com/v1beta/models/",
        retryPolicy: GeminiRetryPolicy = .default,
        maxImages: Int = 6
    ) -> GeminiClientConfiguration {
        GeminiClientConfiguration(
            keychainAccount: "com.sophon.tests.geminiAPIKey",
            defaults: defaults ?? LLMTestSupport.makeDefaults(),
            defaultModel: defaultModel,
            fallbackModel: fallbackModel,
            availableModels: availableModels,
            apiBaseURL: apiBaseURL,
            retryPolicy: retryPolicy,
            maxImages: maxImages,
            logHandler: { _, _ in }
        )
    }
}
