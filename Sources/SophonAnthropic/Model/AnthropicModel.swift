//
//  AnthropicModel.swift
//  SophonAnthropic
//
//  Anthropic (Claude) catalog. Verified against the Claude API model catalog
//  on 2026-09-13: every preset below is current. Fable 5.x, Opus 5 / 4.8 /
//  4.7, and Sonnet 5 reject sampling parameters; the 4.6 and 4.5 lines and
//  Haiku 4.5 accept them. IDs are the undated aliases.
//

import Foundation
import SophonCore

public enum AnthropicModel: LLMModelPreset {
    case claudeOpus5
    case claudeSonnet5
    case claudeHaiku45
    case claudeFable51
    case claudeFable5
    case claudeOpus48
    case claudeOpus47
    case claudeOpus46
    case claudeSonnet46
    case claudeOpus45
    case claudeSonnet45
    case custom(String)

    public static let allStandardCases: [Self] = [
        .claudeOpus5, .claudeSonnet5, .claudeHaiku45, .claudeFable51, .claudeFable5,
        .claudeOpus48, .claudeOpus47, .claudeOpus46, .claudeSonnet46, .claudeOpus45, .claudeSonnet45,
    ]

    /// Sonnet over Opus for the same reason Gemini defaults to Flash over Pro:
    /// end users pay per token on their own key.
    public static let recommendedDefault: Self = .claudeSonnet5
    public static let recommendedFallback: Self = .claudeHaiku45

    public static let freeAccess: LLMProviderFreeAccess = .trialCredit(
        note: "One-time $5 credit for new Console accounts (phone verification required); billed per token afterwards."
    )

    /// Where the user gets an API key, for settings hints.
    public static let keyHintURL = URL(string: "https://platform.claude.com/settings/keys")

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .claudeOpus5:
            LLMModelInfo(
                modelID: "claude-opus-5",
                displayName: "Claude Opus 5",
                storageKey: "claudeOpus5",
                generation: 5.0,
                pricing: LLMModelPricing(input: 5.00, output: 25.00),
                supportsTemperature: false,
                contextWindow: 1_000_000
            )
        case .claudeSonnet5:
            LLMModelInfo(
                modelID: "claude-sonnet-5",
                displayName: "Claude Sonnet 5",
                storageKey: "claudeSonnet5",
                generation: 5.0,
                pricing: LLMModelPricing(input: 2.00, output: 10.00),
                supportsTemperature: false,
                contextWindow: 1_000_000
            )
        case .claudeHaiku45:
            LLMModelInfo(
                modelID: "claude-haiku-4-5",
                displayName: "Claude Haiku 4.5",
                storageKey: "claudeHaiku45",
                generation: 4.5,
                pricing: LLMModelPricing(input: 1.00, output: 5.00),
                contextWindow: 200_000
            )
        case .claudeFable51:
            LLMModelInfo(
                modelID: "claude-fable-5-1",
                displayName: "Claude Fable 5.1",
                storageKey: "claudeFable51",
                generation: 5.1,
                pricing: LLMModelPricing(input: 10.00, output: 50.00),
                supportsTemperature: false,
                contextWindow: 1_000_000
            )
        case .claudeFable5:
            LLMModelInfo(
                modelID: "claude-fable-5",
                displayName: "Claude Fable 5",
                storageKey: "claudeFable5",
                generation: 5.0,
                pricing: LLMModelPricing(input: 10.00, output: 50.00),
                supportsTemperature: false,
                contextWindow: 1_000_000
            )
        case .claudeOpus48:
            LLMModelInfo(
                modelID: "claude-opus-4-8",
                displayName: "Claude Opus 4.8",
                storageKey: "claudeOpus48",
                generation: 4.8,
                pricing: LLMModelPricing(input: 5.00, output: 25.00),
                supportsTemperature: false,
                contextWindow: 1_000_000
            )
        case .claudeOpus47:
            LLMModelInfo(
                modelID: "claude-opus-4-7",
                displayName: "Claude Opus 4.7",
                storageKey: "claudeOpus47",
                generation: 4.7,
                pricing: LLMModelPricing(input: 5.00, output: 25.00),
                supportsTemperature: false,
                contextWindow: 1_000_000
            )
        case .claudeOpus46:
            LLMModelInfo(
                modelID: "claude-opus-4-6",
                displayName: "Claude Opus 4.6",
                storageKey: "claudeOpus46",
                generation: 4.6,
                pricing: LLMModelPricing(input: 5.00, output: 25.00),
                contextWindow: 1_000_000
            )
        case .claudeSonnet46:
            LLMModelInfo(
                modelID: "claude-sonnet-4-6",
                displayName: "Claude Sonnet 4.6",
                storageKey: "claudeSonnet46",
                generation: 4.6,
                pricing: LLMModelPricing(input: 3.00, output: 15.00),
                contextWindow: 1_000_000
            )
        case .claudeOpus45:
            LLMModelInfo(
                modelID: "claude-opus-4-5",
                displayName: "Claude Opus 4.5",
                storageKey: "claudeOpus45",
                generation: 4.5,
                pricing: LLMModelPricing(input: 5.00, output: 25.00),
                contextWindow: 200_000
            )
        case .claudeSonnet45:
            LLMModelInfo(
                modelID: "claude-sonnet-4-5",
                displayName: "Claude Sonnet 4.5",
                storageKey: "claudeSonnet45",
                generation: 4.5,
                pricing: LLMModelPricing(input: 3.00, output: 15.00),
                contextWindow: 200_000
            )
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}
