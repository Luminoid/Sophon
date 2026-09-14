//
//  AnthropicClientConfiguration.swift
//  SophonAnthropic
//
//  Per-app configuration for `AnthropicAPIClient`. Apps construct one of these
//  (typically as a static extension) and keep a single shared client built
//  from it; every app-specific string lives here, not in the package. The
//  availability and API-key helpers (`isAvailable`, `hasAPIKey`, `saveAPIKey`,
//  `maskedAPIKeyDisplay`, ...) come from `LLMProviderConfiguration`.
//

import Foundation
import SophonCore

/// UserDefaults is documented thread-safe, hence the @unchecked conformance.
public struct AnthropicClientConfiguration: @unchecked Sendable, LLMProviderConfiguration {
    public var keychainAccount: String
    public var enabledDefaultsKey: String
    public var modelDefaultsKey: String
    public var customModelDefaultsKey: String
    public var defaults: UserDefaults
    /// Model for new installs with no stored selection. Defaults to
    /// `AnthropicModel.recommendedDefault`, so a Sophon update moves it.
    public var defaultModel: AnthropicModel
    /// Stable safety net when a selected model is retired. Expected to be in
    /// `availableModels`.
    public var fallbackModel: AnthropicModel
    /// The presets this app offers. Defaults to `AnthropicModel.current`. A
    /// `defaultModel` or `fallbackModel` outside it resolves to the first
    /// offered preset.
    public var availableModels: [AnthropicModel]
    /// Base URL of the API version; `messages` and `models` are appended.
    /// Normalized to exactly one trailing slash, so both `.../v1` and
    /// `.../v1/` work.
    public var apiBaseURL: String {
        didSet { apiBaseURL = Self.normalized(baseURL: apiBaseURL) }
    }

    public var apiVersion: String
    /// Required by the Messages API: the output-token ceiling per request.
    public var maxOutputTokens: Int
    /// Reasoning effort; nil leaves the model's default.
    public var effort: AnthropicEffort?
    /// Per-request inactivity timeout (seconds).
    public var requestTimeout: TimeInterval
    /// Overall ceiling for a single request including the upload (seconds).
    public var resourceTimeout: TimeInterval
    public var retryPolicy: LLMRetryPolicy
    /// Cap on images per request; `encodeImages` drops extras with a warning log.
    public var maxImages: Int
    public var logHandler: SophonLogHandler

    public init(
        keychainAccount: String,
        enabledDefaultsKey: String = "ai.anthropicEnabled",
        modelDefaultsKey: String = "ai.anthropicModel",
        customModelDefaultsKey: String = "ai.anthropicCustomModel",
        defaults: UserDefaults = .standard,
        defaultModel: AnthropicModel = .recommendedDefault,
        fallbackModel: AnthropicModel = .recommendedFallback,
        availableModels: [AnthropicModel] = AnthropicModel.current,
        apiBaseURL: String = "https://api.anthropic.com/v1/",
        apiVersion: String = "2023-06-01",
        maxOutputTokens: Int = 16000,
        effort: AnthropicEffort? = nil,
        requestTimeout: TimeInterval = 120,
        resourceTimeout: TimeInterval = 180,
        retryPolicy: LLMRetryPolicy = .default,
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
        self.apiVersion = apiVersion
        self.maxOutputTokens = maxOutputTokens
        self.effort = effort
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.retryPolicy = retryPolicy
        self.maxImages = maxImages
        self.logHandler = logHandler
    }

    /// The model store this configuration describes.
    public var modelStore: AnthropicModelStore {
        AnthropicModelStore(
            defaults: defaults,
            modelDefaultsKey: modelDefaultsKey,
            customModelDefaultsKey: customModelDefaultsKey,
            defaultModel: defaultModel,
            fallbackModel: fallbackModel,
            availableModels: availableModels
        )
    }

    private static func normalized(baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base + "/"
    }
}
