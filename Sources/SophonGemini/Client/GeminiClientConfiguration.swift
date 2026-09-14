//
//  GeminiClientConfiguration.swift
//  SophonGemini
//
//  Per-app configuration for `GeminiAPIClient`. Apps construct one of these
//  (typically as a static extension) and keep a single shared client built
//  from it; every app-specific string lives here, not in the package. The
//  availability and API-key helpers (`isAvailable`, `hasAPIKey`, `saveAPIKey`,
//  `maskedAPIKeyDisplay`, ...) come from `LLMProviderConfiguration`.
//

import Foundation
import SophonCore

/// UserDefaults is documented thread-safe, hence the @unchecked conformance.
public struct GeminiClientConfiguration: @unchecked Sendable, LLMProviderConfiguration {
    /// Keychain account the API key is stored under (e.g. "com.example.geminiAPIKey").
    /// Apps migrating from a hand-rolled client must keep their existing value
    /// so users' saved keys survive.
    public var keychainAccount: String
    public var enabledDefaultsKey: String
    public var modelDefaultsKey: String
    public var customModelDefaultsKey: String
    public var defaults: UserDefaults
    /// Model for new installs with no stored selection. Defaults to
    /// `GeminiModel.recommendedDefault`, so a Sophon update moves it.
    public var defaultModel: GeminiModel
    /// Stable safety net when a selected model is retired. Defaults to
    /// `GeminiModel.recommendedFallback`, a current GA model so the safety net
    /// itself can't 404. Expected to be in `availableModels`.
    public var fallbackModel: GeminiModel
    /// The presets this app offers. Defaults to `GeminiModel.current` (every
    /// non-deprecated preset). A stored model outside this list resolves
    /// through `GeminiModel.successor`, then `fallbackModel`; a `defaultModel`
    /// or `fallbackModel` outside it resolves to the first offered preset.
    public var availableModels: [GeminiModel]
    /// Base URL of the models collection; `<model>:generateContent` and the
    /// listing query are appended. Normalized to exactly one trailing slash,
    /// so both `.../v1beta/models` and `.../v1beta/models/` work.
    public var apiBaseURL: String {
        didSet { apiBaseURL = Self.normalized(baseURL: apiBaseURL) }
    }

    /// Per-request inactivity timeout (seconds).
    public var requestTimeout: TimeInterval
    /// Overall ceiling for a single request including the upload (seconds).
    public var resourceTimeout: TimeInterval
    public var retryPolicy: GeminiRetryPolicy
    /// Cap on images per request; `encodeImages` drops extras with a warning log
    /// (Gemini's inline budget is ~20 MB).
    public var maxImages: Int
    public var logHandler: SophonLogHandler

    public init(
        keychainAccount: String,
        enabledDefaultsKey: String = "ai.geminiEnabled",
        modelDefaultsKey: String = "ai.geminiModel",
        customModelDefaultsKey: String = "ai.geminiCustomModel",
        defaults: UserDefaults = .standard,
        defaultModel: GeminiModel = .recommendedDefault,
        fallbackModel: GeminiModel = .recommendedFallback,
        availableModels: [GeminiModel] = GeminiModel.current,
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
        self.apiBaseURL = Self.normalized(baseURL: apiBaseURL)
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.retryPolicy = retryPolicy
        self.maxImages = maxImages
        self.logHandler = logHandler
    }

    /// The model store this configuration describes.
    public var modelStore: GeminiModelStore {
        GeminiModelStore(configuration: self)
    }

    /// Central availability check: the settings toggle is on AND an API key is
    /// stored. The Gemini-named spelling of `isAvailable`.
    public var isGeminiAvailable: Bool {
        isAvailable
    }

    private static func normalized(baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base + "/"
    }
}
