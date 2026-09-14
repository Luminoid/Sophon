//
//  OpenAICompatibleConfiguration.swift
//  SophonOpenAI
//
//  Per-app configuration for an `OpenAICompatibleClient`. Apps construct one
//  per provider (typically as a static extension) and keep a single shared
//  client built from it; every app-specific string lives here, not in the
//  package. Defaults keys derive from the endpoint's key prefix.
//

import Foundation
import SophonCore

/// UserDefaults is documented thread-safe, hence the @unchecked conformance.
public struct OpenAICompatibleConfiguration<Model: OpenAICompatibleModel>: @unchecked Sendable, LLMProviderConfiguration {
    public var keychainAccount: String
    public var endpoint: OpenAIEndpoint
    public var enabledDefaultsKey: String
    public var modelDefaultsKey: String
    public var customModelDefaultsKey: String
    public var defaults: UserDefaults
    /// Model for new installs with no stored selection. Defaults to the
    /// catalog's `recommendedDefault`, so a Sophon update moves it.
    public var defaultModel: Model
    /// Stable safety net when a selected model is retired. Defaults to the
    /// catalog's `recommendedFallback`.
    public var fallbackModel: Model
    /// The presets this app offers. Defaults to the catalog's `current`.
    public var availableModels: [Model]
    /// Output-token ceiling per request (`max_output_tokens` on the Responses
    /// API, `max_completion_tokens` / `max_tokens` on Chat Completions).
    public var maxOutputTokens: Int
    /// Per-request inactivity timeout (seconds).
    public var requestTimeout: TimeInterval
    /// Overall ceiling for a single request including the upload (seconds).
    public var resourceTimeout: TimeInterval
    public var retryPolicy: LLMRetryPolicy
    /// Cap on images per request; `encodeImages` drops extras with a warning log.
    public var maxImages: Int
    /// App attribution some gateways ask for (OpenRouter's `X-Title`); sent only when set.
    public var appName: String?
    /// App attribution some gateways ask for (OpenRouter's `HTTP-Referer`); sent only when set.
    public var appURL: URL?
    public var logHandler: SophonLogHandler

    public init(
        keychainAccount: String,
        endpoint: OpenAIEndpoint = Model.defaultEndpoint,
        enabledDefaultsKey: String? = nil,
        modelDefaultsKey: String? = nil,
        customModelDefaultsKey: String? = nil,
        defaults: UserDefaults = .standard,
        defaultModel: Model = Model.recommendedDefault,
        fallbackModel: Model = Model.recommendedFallback,
        availableModels: [Model] = Model.current,
        maxOutputTokens: Int = 16000,
        requestTimeout: TimeInterval = 120,
        resourceTimeout: TimeInterval = 180,
        retryPolicy: LLMRetryPolicy = .default,
        maxImages: Int = 6,
        appName: String? = nil,
        appURL: URL? = nil,
        logHandler: @escaping SophonLogHandler = SophonLog.defaultHandler
    ) {
        self.keychainAccount = keychainAccount
        self.endpoint = endpoint
        self.enabledDefaultsKey = enabledDefaultsKey ?? endpoint.enabledDefaultsKey
        self.modelDefaultsKey = modelDefaultsKey ?? endpoint.modelDefaultsKey
        self.customModelDefaultsKey = customModelDefaultsKey ?? endpoint.customModelDefaultsKey
        self.defaults = defaults
        self.defaultModel = defaultModel
        self.fallbackModel = fallbackModel
        self.availableModels = availableModels
        self.maxOutputTokens = maxOutputTokens
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.retryPolicy = retryPolicy
        self.maxImages = maxImages
        self.appName = appName
        self.appURL = appURL
        self.logHandler = logHandler
    }

    /// The model store this configuration describes.
    public var modelStore: LLMModelStore<Model> {
        LLMModelStore(
            defaults: defaults,
            modelDefaultsKey: modelDefaultsKey,
            customModelDefaultsKey: customModelDefaultsKey,
            defaultModel: defaultModel,
            fallbackModel: fallbackModel,
            availableModels: availableModels
        )
    }
}
