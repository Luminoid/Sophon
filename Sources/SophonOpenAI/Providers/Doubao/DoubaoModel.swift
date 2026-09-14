//
//  DoubaoModel.swift
//  SophonOpenAI
//
//  ByteDance Doubao (Volcengine Ark) catalog and endpoint. Verified against
//  volcengine.com and press coverage on 2026-09-13: the Seed 2.1 line
//  (released 2026-06) is current; new accounts get 500K free tokens per
//  model. China-only endpoint, billed in CNY. Variant IDs beyond Pro and
//  Turbo, and json_schema support, are to be confirmed against the Ark
//  model list when a key is at hand.
//

import Foundation
import SophonCore

public enum DoubaoModel: OpenAICompatibleModel {
    case seed21Pro
    case seed21Turbo
    case custom(String)

    public static let allStandardCases: [Self] = [.seed21Pro, .seed21Turbo]
    public static let recommendedDefault: Self = .seed21Turbo
    public static let recommendedFallback: Self = .seed21Pro

    public static let freeAccess: LLMProviderFreeAccess = .newUserQuota(
        note: "500K free tokens per model for new Volcengine Ark accounts (promotional daily allowances run on top from time to time)."
    )

    public static let defaultEndpoint = OpenAIEndpoint(
        displayName: "Doubao",
        keyPrefix: "doubao",
        baseURL: OpenAIEndpoint.url("https://ark.cn-beijing.volces.com/api/v3"),
        wireFormat: .chatCompletions,
        structuredOutputMode: .jsonSchema,
        freeAccess: freeAccess,
        keyHintURL: URL(string: "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey")
    )

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .seed21Pro:
            LLMModelInfo(
                modelID: "doubao-seed-2.1-pro",
                displayName: "Doubao Seed 2.1 Pro",
                storageKey: "seed21Pro",
                generation: 2.1,
                pricing: LLMModelPricing(input: 6, output: 30, currency: .cny),
                contextWindow: 262_144
            )
        case .seed21Turbo:
            LLMModelInfo(modelID: "doubao-seed-2.1-turbo", displayName: "Doubao Seed 2.1 Turbo", storageKey: "seed21Turbo", generation: 2.1, contextWindow: 262_144)
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias DoubaoClientConfiguration = OpenAICompatibleConfiguration<DoubaoModel>
public typealias DoubaoAPIClient = OpenAICompatibleClient<DoubaoModel>

public extension OpenAICompatibleConfiguration where Model == DoubaoModel {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isDoubaoAvailable: Bool { isAvailable }
}
