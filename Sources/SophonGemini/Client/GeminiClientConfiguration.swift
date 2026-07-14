//
//  GeminiClientConfiguration.swift
//  SophonGemini
//
//  Per-app configuration for `GeminiAPIClient`. Apps construct one of these
//  (typically as a static extension) and keep a single shared client built
//  from it; every app-specific string lives here, not in the package.
//

import Foundation
import SophonCore

/// UserDefaults is documented thread-safe, hence the @unchecked conformance.
public struct GeminiClientConfiguration: @unchecked Sendable {
    /// Keychain account the API key is stored under (e.g. "com.example.geminiAPIKey").
    /// Apps migrating from a hand-rolled client must keep their existing value
    /// so users' saved keys survive.
    public var keychainAccount: String
    public var enabledDefaultsKey: String
    public var modelDefaultsKey: String
    public var customModelDefaultsKey: String
    public var defaults: UserDefaults
    /// Model for new installs with no stored selection.
    public var defaultModel: GeminiModel
    /// Stable safety net when a selected model is retired. Keep on a current,
    /// non-deprecated GA model so the safety net itself can't 404.
    public var fallbackModel: GeminiModel
    /// The presets this app offers. A stored model outside this list resolves
    /// through `GeminiModel.successor`, then `fallbackModel`.
    public var availableModels: [GeminiModel]
    public var apiBaseURL: String
    /// Per-request inactivity timeout (seconds).
    public var requestTimeout: TimeInterval
    /// Overall ceiling for a single request including the upload (seconds).
    public var resourceTimeout: TimeInterval
    public var retryPolicy: GeminiRetryPolicy
    /// Cap on images per request (callers enforce; Gemini's inline budget is ~20 MB).
    public var maxImages: Int
    public var logHandler: SophonLogHandler

    public init(
        keychainAccount: String,
        enabledDefaultsKey: String = "ai.geminiEnabled",
        modelDefaultsKey: String = "ai.geminiModel",
        customModelDefaultsKey: String = "ai.geminiCustomModel",
        defaults: UserDefaults = .standard,
        defaultModel: GeminiModel = .gemini31FlashLite,
        fallbackModel: GeminiModel = .gemini31FlashLite,
        availableModels: [GeminiModel] = GeminiModel.allStandardCases,
        apiBaseURL: String = "https://generativelanguage.googleapis.com/v1beta/models/",
        requestTimeout: TimeInterval = 120,
        resourceTimeout: TimeInterval = 180,
        retryPolicy: GeminiRetryPolicy = .default,
        maxImages: Int = 6,
        logHandler: @escaping SophonLogHandler = SophonLog.defaultHandler
    ) {
        self.keychainAccount = keychainAccount
        self.enabledDefaultsKey = enabledDefaultsKey
        self.modelDefaultsKey = modelDefaultsKey
        self.customModelDefaultsKey = customModelDefaultsKey
        self.defaults = defaults
        self.defaultModel = defaultModel
        self.fallbackModel = fallbackModel
        self.availableModels = availableModels
        self.apiBaseURL = apiBaseURL
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.retryPolicy = retryPolicy
        self.maxImages = maxImages
        self.logHandler = logHandler
    }
}
