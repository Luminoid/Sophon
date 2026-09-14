//
//  DeepSeekModel.swift
//  SophonOpenAI
//
//  DeepSeek catalog and endpoint. Verified against api-docs.deepseek.com on
//  2026-09-13: `deepseek-flash` (V4.1 Flash, the only vision model) and
//  `deepseek-v4-pro` are current; the `deepseek-chat` / `deepseek-reasoner`
//  aliases retired 2026-07-24 and `deepseek-v4-flash` on 2026-09-10. Prices
//  are the peak-hour list; off-peak hours bill at half. JSON mode only
//  (`json_object`), no schema enforcement.
//

import Foundation
import SophonCore

public enum DeepSeekModel: OpenAICompatibleModel {
    case deepseekFlash
    case deepseekV4Pro
    case deepseekChat
    case deepseekReasoner
    case deepseekV4Flash
    case custom(String)

    public static let allStandardCases: [Self] = [.deepseekFlash, .deepseekV4Pro, .deepseekChat, .deepseekReasoner, .deepseekV4Flash]
    public static let recommendedDefault: Self = .deepseekFlash
    public static let recommendedFallback: Self = .deepseekV4Pro

    public static let freeAccess: LLMProviderFreeAccess = .trialCredit(
        note: "New accounts receive a one-time token credit; afterwards usage is billed per token, with off-peak hours (outside 01:00-04:00 and 06:00-10:00 UTC on weekdays) at half price."
    )

    public static let defaultEndpoint = OpenAIEndpoint(
        displayName: "DeepSeek",
        keyPrefix: "deepSeek",
        baseURL: OpenAIEndpoint.url("https://api.deepseek.com/v1"),
        wireFormat: .chatCompletions,
        structuredOutputMode: .jsonObject,
        freeAccess: freeAccess,
        keyHintURL: URL(string: "https://platform.deepseek.com/api_keys")
    )

    private static let contextWindow = 1_000_000

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .deepseekFlash:
            LLMModelInfo(
                modelID: "deepseek-flash", displayName: "DeepSeek V4.1 Flash", storageKey: "deepseekFlash",
                generation: 4.1, pricing: LLMModelPricing(input: 0.30, output: 1.20), contextWindow: Self.contextWindow
            )
        case .deepseekV4Pro:
            LLMModelInfo(
                modelID: "deepseek-v4-pro", displayName: "DeepSeek V4 Pro", storageKey: "deepseekV4Pro",
                generation: 4.0, pricing: LLMModelPricing(input: 1.32, output: 3.96), supportsImageInput: false, contextWindow: Self.contextWindow
            )
        case .deepseekChat:
            LLMModelInfo(
                modelID: "deepseek-chat", displayName: "DeepSeek Chat (retired)", storageKey: "deepseekChat",
                lifecycle: .retired(LLMModelInfo.day(2026, 7, 24)), supportsImageInput: false
            )
        case .deepseekReasoner:
            LLMModelInfo(
                modelID: "deepseek-reasoner", displayName: "DeepSeek Reasoner (retired)", storageKey: "deepseekReasoner",
                lifecycle: .retired(LLMModelInfo.day(2026, 7, 24)), supportsImageInput: false
            )
        case .deepseekV4Flash:
            LLMModelInfo(
                modelID: "deepseek-v4-flash", displayName: "DeepSeek V4 Flash (retired)", storageKey: "deepseekV4Flash",
                lifecycle: .retired(LLMModelInfo.day(2026, 9, 10)), generation: 4.0
            )
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? {
        switch self {
        case .deepseekChat, .deepseekV4Flash: .deepseekFlash
        case .deepseekReasoner: .deepseekV4Pro
        default: nil
        }
    }
}

public typealias DeepSeekClientConfiguration = OpenAICompatibleConfiguration<DeepSeekModel>
public typealias DeepSeekAPIClient = OpenAICompatibleClient<DeepSeekModel>

public extension OpenAICompatibleConfiguration where Model == DeepSeekModel {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isDeepSeekAvailable: Bool { isAvailable }
}
