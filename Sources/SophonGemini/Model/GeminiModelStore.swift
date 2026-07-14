//
//  GeminiModelStore.swift
//  SophonGemini
//
//  Persistence and per-app resolution for the model selection. Reads/writes the
//  configured UserDefaults keys, scopes resolution to the app's catalog, and
//  walks the successor chain for models the app has pruned.
//

import Foundation

public struct GeminiModelStore: Sendable {
    public let configuration: GeminiClientConfiguration

    public init(configuration: GeminiClientConfiguration) {
        self.configuration = configuration
    }

    /// The currently selected model. New installs with no stored selection get
    /// `configuration.defaultModel`. A stored model outside the app's catalog is
    /// walked through the successor chain (`GeminiModel.successor`), then falls
    /// back to `configuration.fallbackModel`. `.custom` always passes through.
    public var current: GeminiModel {
        let defaults = configuration.defaults
        guard let key = defaults.string(forKey: configuration.modelDefaultsKey) else {
            return configuration.defaultModel
        }
        let customID = defaults.string(forKey: configuration.customModelDefaultsKey)
        guard let stored = GeminiModel.from(storageKey: key, customModelID: customID) else {
            return configuration.fallbackModel
        }
        return resolveToCatalog(stored)
    }

    /// Persist a model selection (both the storage key and, for `.custom`, the ID).
    public func select(_ model: GeminiModel) {
        configuration.defaults.set(model.storageKey, forKey: configuration.modelDefaultsKey)
        if case let .custom(id) = model {
            configuration.defaults.set(id, forKey: configuration.customModelDefaultsKey)
        }
    }

    /// Persists `configuration.fallbackModel` as the selected model. Called by the
    /// API client when Gemini returns 404 for a retired model so the user's next
    /// call succeeds.
    public func resetToFallback() {
        configuration.defaults.set(configuration.fallbackModel.storageKey, forKey: configuration.modelDefaultsKey)
    }

    private func resolveToCatalog(_ model: GeminiModel) -> GeminiModel {
        if case .custom = model { return model }
        var candidate = model
        while !configuration.availableModels.contains(candidate) {
            guard let next = candidate.successor else {
                return configuration.fallbackModel
            }
            candidate = next
        }
        return candidate
    }
}
