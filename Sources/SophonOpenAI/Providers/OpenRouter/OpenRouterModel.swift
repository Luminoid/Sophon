//
//  OpenRouterModel.swift
//  SophonOpenAI
//
//  OpenRouter catalog and endpoint. Verified against openrouter.ai on
//  2026-09-13: models whose ID ends in `:free` cost nothing (20 RPM, 50 RPD,
//  1,000 RPD after a $10 lifetime credit purchase). The free roster rotates
//  monthly, so the presets are a snapshot; `listFreeModels()` is the durable
//  way to offer what is free today.
//

import Foundation
import SophonCore

public enum OpenRouterModel: OpenAICompatibleModel {
    /// OpenRouter's own router: picks a paid model per request.
    case auto
    case nemotron35LightningFree
    case nexN25ProFree
    case ling30FlashVLFree
    case custom(String)

    public static let allStandardCases: [Self] = [.auto, .nemotron35LightningFree, .nexN25ProFree, .ling30FlashVLFree]
    public static let recommendedDefault: Self = .nemotron35LightningFree
    public static let recommendedFallback: Self = .auto

    public static let freeAccess: LLMProviderFreeAccess = .permanentTier(
        note: "Models ending in :free cost nothing: 20 requests per minute and 50 per day, 1,000 per day after a one-time $10 credit purchase. "
            + "The free roster rotates; call listFreeModels() for today's."
    )

    public static let defaultEndpoint = OpenAIEndpoint(
        displayName: "OpenRouter",
        keyPrefix: "openRouter",
        baseURL: OpenAIEndpoint.url("https://openrouter.ai/api/v1"),
        wireFormat: .chatCompletions,
        structuredOutputMode: .jsonObject,
        freeAccess: freeAccess,
        keyHintURL: URL(string: "https://openrouter.ai/keys")
    )

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .auto:
            LLMModelInfo(modelID: "openrouter/auto", displayName: "Auto (routed, paid)", storageKey: "auto", supportsTemperature: false)
        case .nemotron35LightningFree:
            LLMModelInfo(
                modelID: "nvidia/nemotron-3.5-lightning:free",
                displayName: "Nemotron 3.5 Lightning (free)",
                storageKey: "nemotron35LightningFree",
                tier: .free,
                supportsImageInput: false,
                contextWindow: 1_000_000
            )
        case .nexN25ProFree:
            LLMModelInfo(modelID: "nex-agi/nex-n2.5-pro:free", displayName: "Nex N2.5 Pro (free)", storageKey: "nexN25ProFree", tier: .free, contextWindow: 262_144)
        case .ling30FlashVLFree:
            LLMModelInfo(modelID: "inclusionai/ling-3.0-flash-vl:free", displayName: "Ling 3.0 Flash VL (free)", storageKey: "ling30FlashVLFree", tier: .free, contextWindow: 262_144)
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias OpenRouterClientConfiguration = OpenAICompatibleConfiguration<OpenRouterModel>
public typealias OpenRouterAPIClient = OpenAICompatibleClient<OpenRouterModel>

public extension OpenAICompatibleConfiguration where Model == OpenRouterModel {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isOpenRouterAvailable: Bool { isAvailable }
}

public extension OpenAICompatibleClient where Model == OpenRouterModel {
    /// The models OpenRouter serves free of charge right now (IDs ending in `:free`).
    func listFreeModels() async throws -> [LLMRemoteModel] {
        try await listModels().filter { $0.id.hasSuffix(":free") }
    }

    /// `listFreeModels()` with an explicit key.
    func listFreeModels(apiKey: String) async throws -> [LLMRemoteModel] {
        try await listModels(apiKey: apiKey).filter { $0.id.hasSuffix(":free") }
    }
}
