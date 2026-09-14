//
//  LLMModelStore.swift
//  SophonCore
//
//  Persistence and per-app resolution for a model selection. Reads/writes the
//  configured UserDefaults keys, scopes resolution to the app's catalog, and
//  walks the successor chain for models the app has pruned.
//

import Foundation

/// UserDefaults is documented thread-safe, hence the @unchecked conformance.
public struct LLMModelStore<Model: LLMModelPreset>: @unchecked Sendable {
    public let defaults: UserDefaults
    public let modelDefaultsKey: String
    public let customModelDefaultsKey: String
    /// Model for new installs with no stored selection.
    public let defaultModel: Model
    /// Stable safety net when a selected model is retired.
    public let fallbackModel: Model
    /// The presets this app offers. A stored model outside this list resolves
    /// through `successor`, then `fallbackModel`. `defaultModel` and
    /// `fallbackModel` are expected to be members; should either fall outside
    /// (a narrowed roster), `current` substitutes the first offered preset so
    /// the app never runs a model its own picker can't show.
    public let availableModels: [Model]

    public init(
        defaults: UserDefaults,
        modelDefaultsKey: String,
        customModelDefaultsKey: String,
        defaultModel: Model,
        fallbackModel: Model,
        availableModels: [Model]
    ) {
        self.defaults = defaults
        self.modelDefaultsKey = modelDefaultsKey
        self.customModelDefaultsKey = customModelDefaultsKey
        self.defaultModel = defaultModel
        self.fallbackModel = fallbackModel
        self.availableModels = availableModels
    }

    /// The currently selected model. New installs with no stored selection get
    /// `defaultModel`. A stored model outside the app's catalog is walked
    /// through the successor chain, then falls back to `fallbackModel`.
    /// `custom` always passes through. The result is always a model the app
    /// offers (see `availableModels`).
    public var current: Model {
        guard let key = defaults.string(forKey: modelDefaultsKey) else {
            return offered(defaultModel)
        }
        let customID = defaults.string(forKey: customModelDefaultsKey)
        guard let stored = Model.from(storageKey: key, customModelID: customID) else {
            return offered(fallbackModel)
        }
        return resolveToCatalog(stored)
    }

    /// Persist a model selection (both the storage key and, for `custom`, the ID).
    public func select(_ model: Model) {
        defaults.set(model.storageKey, forKey: modelDefaultsKey)
        if let customID = model.customModelID {
            defaults.set(customID, forKey: customModelDefaultsKey)
        }
    }

    /// Persists `fallbackModel` as the selected model. Called by the API client
    /// when the provider reports the selected model as retired, so the user's
    /// next call succeeds.
    public func resetToFallback() {
        select(fallbackModel)
    }

    private func resolveToCatalog(_ model: Model) -> Model {
        if model.isCustom { return model }
        var candidate = model
        // Hop cap: a catalog edit that accidentally forms a successor cycle must
        // resolve to the fallback, not hang every `current` read.
        var hops = 0
        while !availableModels.contains(candidate) {
            guard hops < Model.allStandardCases.count, let next = candidate.successor else {
                return offered(fallbackModel)
            }
            candidate = next
            hops += 1
        }
        return candidate
    }

    /// `model` when the app offers it (custom IDs always do), else the first
    /// offered preset; `model` itself when the roster is empty.
    private func offered(_ model: Model) -> Model {
        if model.isCustom || availableModels.contains(model) { return model }
        return availableModels.first ?? model
    }
}
