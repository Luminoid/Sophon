//
//  KimiModel.swift
//  SophonOpenAI
//
//  Moonshot Kimi catalog and endpoints. Verified against platform.kimi.ai on
//  2026-09-13: Kimi K3 (1M context) and K2.6 are the general models, the
//  K2.7 Code pair is tuned for coding. The China site (api.moonshot.cn,
//  billed in CNY with a ¥15 signup credit) and the international site
//  (api.moonshot.ai, USD) are separate accounts and keys. Prices are the
//  international list. JSON mode only (`json_object`).
//

import Foundation
import SophonCore

public enum KimiModel: OpenAICompatibleModel {
    case kimiK3
    case kimiK26
    case kimiK27Code
    case kimiK27CodeHighSpeed
    case custom(String)

    public static let allStandardCases: [Self] = [.kimiK3, .kimiK26, .kimiK27Code, .kimiK27CodeHighSpeed]
    public static let recommendedDefault: Self = .kimiK26
    public static let recommendedFallback: Self = .kimiK3

    public static let freeAccess: LLMProviderFreeAccess = .trialCredit(
        note: "¥15 signup credit on the China platform; international accounts are billed from the first token."
    )

    public static func endpoint(region: OpenAIEndpointRegion) -> OpenAIEndpoint {
        switch region {
        case .international:
            OpenAIEndpoint(
                displayName: "Kimi",
                keyPrefix: "kimi",
                baseURL: OpenAIEndpoint.url("https://api.moonshot.ai/v1"),
                wireFormat: .chatCompletions,
                structuredOutputMode: .jsonObject,
                freeAccess: freeAccess,
                keyHintURL: URL(string: "https://platform.kimi.ai/console/api-keys")
            )
        case .china:
            OpenAIEndpoint(
                displayName: "Kimi",
                keyPrefix: "kimi",
                baseURL: OpenAIEndpoint.url("https://api.moonshot.cn/v1"),
                wireFormat: .chatCompletions,
                structuredOutputMode: .jsonObject,
                freeAccess: freeAccess,
                keyHintURL: URL(string: "https://platform.moonshot.cn/console/api-keys")
            )
        }
    }

    public static let defaultEndpoint = endpoint(region: .international)

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .kimiK3:
            LLMModelInfo(modelID: "kimi-k3", displayName: "Kimi K3", storageKey: "kimiK3", generation: 3.0, pricing: LLMModelPricing(input: 3.00, output: 15.00), contextWindow: 1_048_576)
        case .kimiK26:
            LLMModelInfo(modelID: "kimi-k2.6", displayName: "Kimi K2.6", storageKey: "kimiK26", generation: 2.6, pricing: LLMModelPricing(input: 0.95, output: 4.00), contextWindow: 262_144)
        case .kimiK27Code:
            LLMModelInfo(
                modelID: "kimi-k2.7-code",
                displayName: "Kimi K2.7 Code",
                storageKey: "kimiK27Code",
                generation: 2.7,
                pricing: LLMModelPricing(input: 0.95, output: 4.00),
                supportsImageInput: false,
                contextWindow: 262_144
            )
        case .kimiK27CodeHighSpeed:
            LLMModelInfo(
                modelID: "kimi-k2.7-code-highspeed",
                displayName: "Kimi K2.7 Code (high speed)",
                storageKey: "kimiK27CodeHighSpeed",
                generation: 2.7,
                pricing: LLMModelPricing(input: 1.90, output: 8.00),
                supportsImageInput: false,
                contextWindow: 262_144
            )
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias KimiClientConfiguration = OpenAICompatibleConfiguration<KimiModel>
public typealias KimiAPIClient = OpenAICompatibleClient<KimiModel>

public extension OpenAICompatibleConfiguration where Model == KimiModel {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isKimiAvailable: Bool { isAvailable }
}
