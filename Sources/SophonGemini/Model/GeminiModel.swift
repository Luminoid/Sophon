//
//  GeminiModel.swift
//  SophonGemini
//
//  Gemini API model catalog. The union of every preset the consuming apps have
//  ever shipped, so stored storage keys keep resolving; per-app availability is
//  scoped by `GeminiClientConfiguration.availableModels` via `GeminiModelStore`.
//

import Foundation

/// Gemini API model selection. Persisted as a stable storage key in
/// `UserDefaults` so a renamed display string never strands a user's choice.
public enum GeminiModel: Equatable, Sendable {
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

    /// The API model identifier used in the request URL.
    public var modelID: String {
        switch self {
        case .gemini25FlashLite: "gemini-2.5-flash-lite"
        case .gemini25Flash: "gemini-2.5-flash"
        case .gemini25Pro: "gemini-2.5-pro"
        case .gemini3Flash: "gemini-3-flash-preview"
        case .gemini31FlashLite: "gemini-3.1-flash-lite"
        case .gemini31Pro: "gemini-3.1-pro-preview"
        case .gemini35FlashLite: "gemini-3.5-flash-lite"
        case .gemini35Flash: "gemini-3.5-flash"
        case .gemini36Flash: "gemini-3.6-flash"
        case .gemini37Flash: "gemini-3.7-flash"
        case .gemini38Flash: "gemini-3.8-flash"
        case let .custom(id): id
        }
    }

    public var displayName: String {
        switch self {
        case .gemini25FlashLite: "Gemini 2.5 Flash-Lite"
        case .gemini25Flash: "Gemini 2.5 Flash"
        case .gemini25Pro: "Gemini 2.5 Pro"
        case .gemini3Flash: "Gemini 3 Flash (Preview)"
        case .gemini31FlashLite: "Gemini 3.1 Flash-Lite"
        case .gemini31Pro: "Gemini 3.1 Pro (Preview)"
        case .gemini35FlashLite: "Gemini 3.5 Flash-Lite"
        case .gemini35Flash: "Gemini 3.5 Flash"
        case .gemini36Flash: "Gemini 3.6 Flash"
        case .gemini37Flash: "Gemini 3.7 Flash"
        case .gemini38Flash: "Gemini 3.8 Flash"
        case let .custom(id): id
        }
    }

    /// Storage key for UserDefaults persistence.
    public var storageKey: String {
        switch self {
        case .gemini25FlashLite: "gemini25FlashLite"
        case .gemini25Flash: "gemini25Flash"
        case .gemini25Pro: "gemini25Pro"
        case .gemini3Flash: "gemini3Flash"
        case .gemini31FlashLite: "gemini31FlashLite"
        case .gemini31Pro: "gemini31Pro"
        case .gemini35FlashLite: "gemini35FlashLite"
        case .gemini35Flash: "gemini35Flash"
        case .gemini36Flash: "gemini36Flash"
        case .gemini37Flash: "gemini37Flash"
        case .gemini38Flash: "gemini38Flash"
        case .custom: "custom"
        }
    }

    /// Google's documented replacement for a deprecated preset, or the closest
    /// same-tier upgrade for presets an app prunes. Verified against the models,
    /// deprecations, and pricing pages 2026-09-05: the stable 2.5 family still has
    /// no announced shutdown date (only its previews are retired); 3 Flash Preview
    /// is deprecated with 3.6 Flash as its documented replacement; 3.1 Flash-Lite
    /// shuts down 2027-05-07 with 3.5 Flash-Lite as its documented replacement;
    /// 3.5 Flash-Lite and 3.5/3.6/3.7/3.8 Flash are GA with no shutdown date and
    /// ALL have a free tier (3.7 Flash GA 2026-08-13, 3.8 Flash GA 2026-09-02,
    /// both at 3.6 Flash's introductory pricing through 2026-12-31); the Pro line
    /// remains topped by 3.1 Pro (paid-only; no newer Pro exists). Live GA presets
    /// deliberately carry no successor: an edge is added only when Google
    /// deprecates a preset or an app prunes it.
    /// `GeminiModelStore` walks this chain when a stored model is outside the
    /// app's catalog, so existing users land on the closest successor, not the
    /// fallback.
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

    /// Reconstruct from a storage key (and optional custom model ID). Returns nil
    /// for an unknown key, or for a `"custom"` key paired with a missing / blank ID,
    /// so the caller can substitute its configured fallback rather than hitting the
    /// API with an empty model name (a confusing 404 on the next call).
    public static func from(storageKey: String, customModelID: String? = nil) -> Self? {
        switch storageKey {
        case "gemini25FlashLite": .gemini25FlashLite
        case "gemini25Flash": .gemini25Flash
        case "gemini25Pro": .gemini25Pro
        case "gemini3Flash": .gemini3Flash
        case "gemini31FlashLite": .gemini31FlashLite
        case "gemini31Pro": .gemini31Pro
        case "gemini35FlashLite": .gemini35FlashLite
        case "gemini35Flash": .gemini35Flash
        case "gemini36Flash": .gemini36Flash
        case "gemini37Flash": .gemini37Flash
        case "gemini38Flash": .gemini38Flash
        case "custom":
            if let id = customModelID, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                .custom(id)
            } else {
                nil
            }
        default: nil
        }
    }
}
