//
//  LLMModelPreset.swift
//  SophonCore
//
//  What a provider's model catalog enum provides, and the adoption helpers
//  every catalog gets for free: `current`, `currentFreeTier`, generation and
//  capability filters, and storage-key round-tripping.
//

import Foundation

/// A provider's model catalog: a fixed set of presets plus a `custom` escape
/// hatch, each carrying `LLMModelInfo`. Catalogs are enums so persisted storage
/// keys stay stable and apps can pattern-match on presets.
public protocol LLMModelPreset: Equatable, Sendable {
    /// Every preset (excludes `custom`), in catalog order.
    static var allStandardCases: [Self] { get }
    /// The preset Sophon recommends for new installs. Updating Sophon moves it.
    static var recommendedDefault: Self { get }
    /// The safety net when a selected model turns out to be retired. Must stay
    /// on a current model so the safety net itself can't fail.
    static var recommendedFallback: Self { get }
    /// How the provider can be used without paying.
    static var freeAccess: LLMProviderFreeAccess { get }
    /// Where the user gets an API key, for settings hints. Defaults to nil.
    static var keyHintURL: URL? { get }
    /// A caller-supplied model ID outside the catalog.
    static func custom(_ modelID: String) -> Self
    /// The ID of a `custom` value; nil for presets.
    var customModelID: String? { get }
    var info: LLMModelInfo { get }
    /// The provider's documented replacement for a deprecated preset, or the
    /// closest same-tier upgrade for presets an app prunes. `LLMModelStore`
    /// walks this chain when a stored model is outside the app's catalog.
    var successor: Self? { get }
}

public extension LLMModelPreset {
    static var keyHintURL: URL? { nil }

    /// The API model identifier used in requests.
    var modelID: String { info.modelID }
    var displayName: String { info.displayName }
    /// Storage key for UserDefaults persistence.
    var storageKey: String { info.storageKey }
    var isCustom: Bool { customModelID != nil }
    /// Deprecated or retired: the provider has announced or completed a shutdown.
    var isDeprecated: Bool { !info.lifecycle.isCurrent }
    /// Part of the provider's permanent free tier.
    var hasFreeTier: Bool { info.tier == .free }

    /// Every preset the provider still serves with no shutdown announced, in
    /// catalog order. The "adopt all non-deprecated models" roster.
    static var current: [Self] {
        allStandardCases.filter(\.info.lifecycle.isCurrent)
    }

    /// `current` narrowed to the provider's permanent free tier.
    static var currentFreeTier: [Self] {
        current.filter(\.hasFreeTier)
    }

    /// `current` narrowed to models that accept image input.
    static var currentWithImageInput: [Self] {
        current.filter(\.info.supportsImageInput)
    }

    /// `current` narrowed to generation `minimumGeneration` and newer. Presets
    /// with no generation are excluded.
    static func current(minimumGeneration: Double) -> [Self] {
        current.filter { preset in
            guard let generation = preset.info.generation else { return false }
            return generation >= minimumGeneration
        }
    }

    /// Reconstruct from a storage key (and optional custom model ID). Returns nil
    /// for an unknown key, or for a `"custom"` key paired with a missing / blank ID,
    /// so the caller can substitute its configured fallback rather than hitting the
    /// API with an empty model name (a confusing 404 on the next call).
    static func from(storageKey: String, customModelID: String? = nil) -> Self? {
        if storageKey == LLMModelInfo.custom("").storageKey {
            guard let customModelID, !customModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return custom(customModelID)
        }
        return allStandardCases.first { $0.storageKey == storageKey }
    }
}
