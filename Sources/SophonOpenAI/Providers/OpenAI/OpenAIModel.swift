//
//  OpenAIModel.swift
//  SophonOpenAI
//
//  OpenAI catalog and endpoint. Verified against developers.openai.com
//  (models, pricing, deprecations) on 2026-09-13: GPT-6 Astra and the GPT-5.6
//  Sol / Terra / Luna line are current; the GPT-5 line shuts down 2026-12-11.
//  Reasoning models (GPT-5 and later) reject sampling parameters.
//

import Foundation
import SophonCore

public enum OpenAIModel: OpenAICompatibleModel {
    case gpt6Astra
    case gpt56Sol
    case gpt56Terra
    case gpt56Luna
    case gpt55
    case gpt54
    case gpt54Mini
    case gpt54Nano
    case gpt5
    case gpt5Mini
    case gpt5Nano
    case gpt41
    case gpt41Mini
    case gpt41Nano
    case gpt4o
    case gpt4oMini
    case custom(String)

    public static let allStandardCases: [Self] = [
        .gpt6Astra, .gpt56Sol, .gpt56Terra, .gpt56Luna,
        .gpt55, .gpt54, .gpt54Mini, .gpt54Nano,
        .gpt5, .gpt5Mini, .gpt5Nano,
        .gpt41, .gpt41Mini, .gpt41Nano, .gpt4o, .gpt4oMini,
    ]

    /// Cheapest current multimodal model of the flagship line.
    public static let recommendedDefault: Self = .gpt56Luna
    /// Current, cheap, and from a different line than the default.
    public static let recommendedFallback: Self = .gpt54Mini

    public static let freeAccess: LLMProviderFreeAccess = .trialCredit(
        note: "One-time $15 trial credit for new accounts (30 days); complimentary daily tokens (up to 1M/10M per day on eligible models) for organizations that opt into data sharing."
    )

    public static let defaultEndpoint = OpenAIEndpoint(
        displayName: "OpenAI",
        keyPrefix: "openAI",
        baseURL: OpenAIEndpoint.url("https://api.openai.com/v1"),
        wireFormat: .responses,
        structuredOutputMode: .jsonSchema,
        maxTokensField: .maxCompletionTokens,
        freeAccess: freeAccess,
        keyHintURL: URL(string: "https://platform.openai.com/api-keys")
    )

    private static let shutdownGPT5 = LLMModelInfo.day(2026, 12, 11)

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .gpt6Astra:
            LLMModelInfo(
                modelID: "gpt-6-astra", displayName: "GPT-6 Astra", storageKey: "gpt6Astra",
                generation: 6.0, releaseDate: LLMModelInfo.day(2026, 9, 3), pricing: LLMModelPricing(input: 10.00, output: 50.00),
                supportsTemperature: false, contextWindow: 1_050_000
            )
        case .gpt56Sol:
            LLMModelInfo(
                modelID: "gpt-5.6-sol", displayName: "GPT-5.6 Sol", storageKey: "gpt56Sol",
                generation: 5.6, pricing: LLMModelPricing(input: 4.00, output: 20.00),
                supportsTemperature: false, contextWindow: 1_050_000
            )
        case .gpt56Terra:
            LLMModelInfo(
                modelID: "gpt-5.6-terra", displayName: "GPT-5.6 Terra", storageKey: "gpt56Terra",
                generation: 5.6, pricing: LLMModelPricing(input: 2.00, output: 12.00),
                supportsTemperature: false, contextWindow: 1_050_000
            )
        case .gpt56Luna:
            LLMModelInfo(
                modelID: "gpt-5.6-luna", displayName: "GPT-5.6 Luna", storageKey: "gpt56Luna",
                generation: 5.6, pricing: LLMModelPricing(input: 0.20, output: 1.20),
                supportsTemperature: false, contextWindow: 1_050_000
            )
        case .gpt55:
            LLMModelInfo(
                modelID: "gpt-5.5", displayName: "GPT-5.5", storageKey: "gpt55",
                generation: 5.5, pricing: LLMModelPricing(input: 5.00, output: 30.00),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt54:
            LLMModelInfo(
                modelID: "gpt-5.4", displayName: "GPT-5.4", storageKey: "gpt54",
                generation: 5.4, pricing: LLMModelPricing(input: 2.50, output: 15.00),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt54Mini:
            LLMModelInfo(
                modelID: "gpt-5.4-mini", displayName: "GPT-5.4 mini", storageKey: "gpt54Mini",
                generation: 5.4, pricing: LLMModelPricing(input: 0.75, output: 4.50),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt54Nano:
            LLMModelInfo(
                modelID: "gpt-5.4-nano", displayName: "GPT-5.4 nano", storageKey: "gpt54Nano",
                generation: 5.4, pricing: LLMModelPricing(input: 0.20, output: 1.25),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt5:
            LLMModelInfo(
                modelID: "gpt-5", displayName: "GPT-5", storageKey: "gpt5",
                lifecycle: .deprecated(shutdown: Self.shutdownGPT5), generation: 5.0, pricing: LLMModelPricing(input: 1.25, output: 10.00),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt5Mini:
            LLMModelInfo(
                modelID: "gpt-5-mini", displayName: "GPT-5 mini", storageKey: "gpt5Mini",
                lifecycle: .deprecated(shutdown: Self.shutdownGPT5), generation: 5.0, pricing: LLMModelPricing(input: 0.25, output: 2.00),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt5Nano:
            LLMModelInfo(
                modelID: "gpt-5-nano", displayName: "GPT-5 nano", storageKey: "gpt5Nano",
                lifecycle: .deprecated(shutdown: Self.shutdownGPT5), generation: 5.0, pricing: LLMModelPricing(input: 0.05, output: 0.40),
                supportsTemperature: false, contextWindow: 400_000
            )
        case .gpt41:
            LLMModelInfo(
                modelID: "gpt-4.1", displayName: "GPT-4.1", storageKey: "gpt41",
                generation: 4.1, pricing: LLMModelPricing(input: 2.00, output: 8.00), contextWindow: 1_047_576
            )
        case .gpt41Mini:
            LLMModelInfo(
                modelID: "gpt-4.1-mini", displayName: "GPT-4.1 mini", storageKey: "gpt41Mini",
                generation: 4.1, pricing: LLMModelPricing(input: 0.40, output: 1.60), contextWindow: 1_047_576
            )
        case .gpt41Nano:
            LLMModelInfo(
                modelID: "gpt-4.1-nano", displayName: "GPT-4.1 nano", storageKey: "gpt41Nano",
                generation: 4.1, pricing: LLMModelPricing(input: 0.10, output: 0.40), contextWindow: 1_047_576
            )
        case .gpt4o:
            LLMModelInfo(
                modelID: "gpt-4o", displayName: "GPT-4o", storageKey: "gpt4o",
                generation: 4.0, pricing: LLMModelPricing(input: 2.50, output: 10.00), contextWindow: 128_000
            )
        case .gpt4oMini:
            LLMModelInfo(
                modelID: "gpt-4o-mini", displayName: "GPT-4o mini", storageKey: "gpt4oMini",
                generation: 4.0, pricing: LLMModelPricing(input: 0.15, output: 0.60), contextWindow: 128_000
            )
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    /// OpenAI's documented replacements for the GPT-5 line (shutdown 2026-12-11).
    public var successor: Self? {
        switch self {
        case .gpt5: .gpt56Sol
        case .gpt5Mini: .gpt56Terra
        case .gpt5Nano: .gpt56Luna
        default: nil
        }
    }
}

public typealias OpenAIClientConfiguration = OpenAICompatibleConfiguration<OpenAIModel>
public typealias OpenAIAPIClient = OpenAICompatibleClient<OpenAIModel>
