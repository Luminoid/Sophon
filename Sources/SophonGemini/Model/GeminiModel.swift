//
//  GeminiModel.swift
//  SophonGemini
//
//  Gemini API model catalog. The union of every preset the consuming apps have
//  ever shipped, so stored storage keys keep resolving; per-app availability is
//  scoped by `GeminiClientConfiguration.availableModels` via `GeminiModelStore`.
//
//  Metadata verified against Google's models, deprecations, and pricing pages
//  on 2026-09-13. Re-verify there before promoting a preset to
//  `recommendedDefault`; `GeminiModelTests` locks the free-tier rule.
//

import Foundation
import SophonCore

/// Gemini API model selection. Persisted as a stable storage key in
/// `UserDefaults` so a renamed display string never strands a user's choice.
public enum GeminiModel: LLMModelPreset {
    case gemini25FlashLite
    case gemini25Flash
    case gemini25Pro
    case gemini3Flash
    case gemini31FlashLite
    case gemini31Pro
    case gemini35FlashLite
    case gemini35Flash
    case gemini36Flash
    case gemini37Flash
    case gemini38Flash
    case custom(String)

    /// All predefined cases (excludes `.custom`).
    public static let allStandardCases: [Self] = [
        .gemini25FlashLite, .gemini25Flash, .gemini25Pro,
        .gemini3Flash, .gemini31FlashLite, .gemini31Pro,
        .gemini35FlashLite, .gemini35Flash, .gemini36Flash, .gemini37Flash, .gemini38Flash,
    ]

    /// Newest GA Flash model with a free tier.
    public static let recommendedDefault: Self = .gemini38Flash
    /// GA Flash-Lite model with a free tier and no shutdown announced.
    public static let recommendedFallback: Self = .gemini35FlashLite

    public static let freeAccess: LLMProviderFreeAccess = .permanentTier(
        note: "Google AI Studio keys call the Flash, Flash-Lite, and 2.5 Pro models with no billing account (rate-limited); 3.1 Pro is paid-only."
    )

    private static let contextWindow = 1_048_576

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .gemini25FlashLite:
            LLMModelInfo(
                modelID: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash-Lite", storageKey: "gemini25FlashLite",
                lifecycle: .current, tier: .free, generation: 2.5, releaseDate: LLMModelInfo.day(2025, 7, 22),
                pricing: LLMModelPricing(input: 0.10, output: 0.40), contextWindow: Self.contextWindow
            )
        case .gemini25Flash:
            LLMModelInfo(
                modelID: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", storageKey: "gemini25Flash",
                lifecycle: .current, tier: .free, generation: 2.5, releaseDate: LLMModelInfo.day(2025, 6, 17),
                pricing: LLMModelPricing(input: 0.30, output: 2.50), contextWindow: Self.contextWindow
            )
        case .gemini25Pro:
            LLMModelInfo(
                modelID: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", storageKey: "gemini25Pro",
                lifecycle: .current, tier: .free, generation: 2.5, releaseDate: LLMModelInfo.day(2025, 6, 17),
                pricing: LLMModelPricing(input: 1.25, output: 10.00), contextWindow: Self.contextWindow
            )
        case .gemini3Flash:
            // Deprecated with no shutdown date; Google names 3.6 Flash as the replacement.
            LLMModelInfo(
                modelID: "gemini-3-flash-preview", displayName: "Gemini 3 Flash (Preview)", storageKey: "gemini3Flash",
                lifecycle: .deprecated(shutdown: nil), tier: .free, generation: 3.0, releaseDate: LLMModelInfo.day(2025, 12, 17),
                pricing: LLMModelPricing(input: 0.50, output: 3.00), contextWindow: Self.contextWindow
            )
        case .gemini31FlashLite:
            LLMModelInfo(
                modelID: "gemini-3.1-flash-lite", displayName: "Gemini 3.1 Flash-Lite", storageKey: "gemini31FlashLite",
                lifecycle: .deprecated(shutdown: LLMModelInfo.day(2027, 5, 7)), tier: .free, generation: 3.1, releaseDate: LLMModelInfo.day(2026, 5, 7),
                pricing: LLMModelPricing(input: 0.25, output: 1.50), contextWindow: Self.contextWindow
            )
        case .gemini31Pro:
            LLMModelInfo(
                modelID: "gemini-3.1-pro-preview", displayName: "Gemini 3.1 Pro (Preview)", storageKey: "gemini31Pro",
                lifecycle: .current, tier: .paid, generation: 3.1, releaseDate: LLMModelInfo.day(2026, 2, 19),
                pricing: LLMModelPricing(input: 2.00, output: 12.00), contextWindow: Self.contextWindow
            )
        case .gemini35FlashLite:
            LLMModelInfo(
                modelID: "gemini-3.5-flash-lite", displayName: "Gemini 3.5 Flash-Lite", storageKey: "gemini35FlashLite",
                lifecycle: .current, tier: .free, generation: 3.5, releaseDate: LLMModelInfo.day(2026, 7, 21),
                pricing: LLMModelPricing(input: 0.30, output: 2.50), contextWindow: Self.contextWindow
            )
        case .gemini35Flash:
            LLMModelInfo(
                modelID: "gemini-3.5-flash", displayName: "Gemini 3.5 Flash", storageKey: "gemini35Flash",
                lifecycle: .current, tier: .free, generation: 3.5, releaseDate: LLMModelInfo.day(2026, 5, 19),
                pricing: LLMModelPricing(input: 1.50, output: 9.00), contextWindow: Self.contextWindow
            )
        case .gemini36Flash:
            LLMModelInfo(
                modelID: "gemini-3.6-flash", displayName: "Gemini 3.6 Flash", storageKey: "gemini36Flash",
                lifecycle: .current, tier: .free, generation: 3.6,
                pricing: LLMModelPricing(input: 0.75, output: 3.75), contextWindow: Self.contextWindow
            )
        case .gemini37Flash:
            LLMModelInfo(
                modelID: "gemini-3.7-flash", displayName: "Gemini 3.7 Flash", storageKey: "gemini37Flash",
                lifecycle: .current, tier: .free, generation: 3.7, releaseDate: LLMModelInfo.day(2026, 8, 13),
                pricing: LLMModelPricing(input: 0.75, output: 3.75), contextWindow: Self.contextWindow
            )
        case .gemini38Flash:
            // Introductory pricing through 2026-12-31.
            LLMModelInfo(
                modelID: "gemini-3.8-flash", displayName: "Gemini 3.8 Flash", storageKey: "gemini38Flash",
                lifecycle: .current, tier: .free, generation: 3.8, releaseDate: LLMModelInfo.day(2026, 9, 2),
                pricing: LLMModelPricing(input: 0.75, output: 3.75), contextWindow: Self.contextWindow
            )
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    /// Google's documented replacement for a deprecated preset, or the closest
    /// same-tier upgrade for presets an app prunes. The stable 2.5 family has no
    /// announced shutdown date (only its previews are retired); 3 Flash Preview
    /// is deprecated with 3.6 Flash as its documented replacement; 3.1 Flash-Lite
    /// shuts down 2027-05-07 with 3.5 Flash-Lite as its documented replacement.
    /// Live GA presets deliberately carry no successor: an edge is added only
    /// when Google deprecates a preset or an app prunes it. `GeminiModelStore`
    /// walks this chain when a stored model is outside the app's catalog, so
    /// existing users land on the closest successor, not the fallback.
    public var successor: Self? {
        switch self {
        case .gemini25FlashLite: .gemini31FlashLite
        case .gemini25Flash: .gemini35Flash
        case .gemini25Pro: .gemini31Pro
        case .gemini3Flash: .gemini36Flash
        case .gemini31FlashLite: .gemini35FlashLite
        default: nil
        }
    }
}
