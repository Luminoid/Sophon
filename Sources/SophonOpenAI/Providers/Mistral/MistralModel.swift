//
//  MistralModel.swift
//  SophonOpenAI
//
//  Mistral catalog and endpoint. Verified against docs.mistral.ai on
//  2026-09-13: Medium 3.5, Small 4, Large 3, and the Ministral 3 line are
//  current (Codestral retired 2026-07-31). The Experiment plan calls every
//  model free of charge, rate-limited, in exchange for opting into data
//  training. The `-latest` aliases track each line's newest release.
//

import Foundation
import SophonCore

public enum MistralModel: OpenAICompatibleModel {
    case mistralMedium
    case mistralSmall
    case mistralLarge
    case ministral14B
    case ministral8B
    case ministral3B
    case custom(String)

    public static let allStandardCases: [Self] = [.mistralMedium, .mistralSmall, .mistralLarge, .ministral14B, .ministral8B, .ministral3B]
    public static let recommendedDefault: Self = .mistralSmall
    public static let recommendedFallback: Self = .ministral8B

    public static let freeAccess: LLMProviderFreeAccess = .permanentTier(
        note: "Experiment plan: every model free of charge with tight rate limits (about 1 request per second, roughly 1B tokens per month), in exchange for opting into data training."
    )

    public static let defaultEndpoint = OpenAIEndpoint(
        displayName: "Mistral",
        keyPrefix: "mistral",
        baseURL: OpenAIEndpoint.url("https://api.mistral.ai/v1"),
        wireFormat: .chatCompletions,
        structuredOutputMode: .jsonSchema,
        freeAccess: freeAccess,
        keyHintURL: URL(string: "https://console.mistral.ai/api-keys")
    )

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .mistralMedium:
            LLMModelInfo(modelID: "mistral-medium-latest", displayName: "Mistral Medium 3.5", storageKey: "mistralMedium", tier: .free, generation: 3.5)
        case .mistralSmall:
            LLMModelInfo(modelID: "mistral-small-latest", displayName: "Mistral Small 4", storageKey: "mistralSmall", tier: .free, generation: 4.0, supportsImageInput: false)
        case .mistralLarge:
            LLMModelInfo(modelID: "mistral-large-latest", displayName: "Mistral Large 3", storageKey: "mistralLarge", tier: .free, generation: 3.0)
        case .ministral14B:
            LLMModelInfo(modelID: "ministral-14b-latest", displayName: "Ministral 3 14B", storageKey: "ministral14B", tier: .free, generation: 3.0)
        case .ministral8B:
            LLMModelInfo(modelID: "ministral-8b-latest", displayName: "Ministral 3 8B", storageKey: "ministral8B", tier: .free, generation: 3.0)
        case .ministral3B:
            LLMModelInfo(modelID: "ministral-3b-latest", displayName: "Ministral 3 3B", storageKey: "ministral3B", tier: .free, generation: 3.0)
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias MistralClientConfiguration = OpenAICompatibleConfiguration<MistralModel>
public typealias MistralAPIClient = OpenAICompatibleClient<MistralModel>

public extension OpenAICompatibleConfiguration where Model == MistralModel {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isMistralAvailable: Bool { isAvailable }
}
