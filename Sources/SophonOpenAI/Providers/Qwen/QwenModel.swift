//
//  QwenModel.swift
//  SophonOpenAI
//
//  Alibaba Model Studio (Qwen) catalog and endpoints. Verified against
//  help.aliyun.com/zh/model-studio on 2026-09-13. The China site
//  (dashscope.aliyuncs.com, Beijing region) and the international site
//  (dashscope-intl.aliyuncs.com, Singapore region) are separate accounts and
//  keys; both grant new users 1M free tokens per model for 90 days. Prices are
//  the China site's base tier in CNY; larger prompts bill in higher tiers.
//  The `qwen-plus` / `qwen-flash` / `qwen-turbo` aliases track the newest
//  release of each line. JSON mode only (`json_object`).
//

import Foundation
import SophonCore

public enum QwenModel: OpenAICompatibleModel {
    case qwen38Max
    case qwen37Max
    case qwen37Plus
    case qwen35Plus
    case qwenPlus
    case qwen38Flash
    case qwen37Flash
    case qwen35Flash
    case qwenFlash
    case qwenTurbo
    case custom(String)

    public static let allStandardCases: [Self] = [
        .qwen38Max, .qwen37Max, .qwen37Plus, .qwen35Plus, .qwenPlus,
        .qwen38Flash, .qwen37Flash, .qwen35Flash, .qwenFlash, .qwenTurbo,
    ]

    /// The Flash alias: cheapest line, always the newest release.
    public static let recommendedDefault: Self = .qwenFlash
    public static let recommendedFallback: Self = .qwenTurbo

    public static let freeAccess: LLMProviderFreeAccess = .newUserQuota(
        note: "1M free tokens per model for 90 days after activating Model Studio (Beijing region on the China site, Singapore region on the international site)."
    )

    public static func endpoint(region: OpenAIEndpointRegion) -> OpenAIEndpoint {
        switch region {
        case .international:
            OpenAIEndpoint(
                displayName: "Qwen",
                keyPrefix: "qwen",
                baseURL: OpenAIEndpoint.url("https://dashscope-intl.aliyuncs.com/compatible-mode/v1"),
                wireFormat: .chatCompletions,
                structuredOutputMode: .jsonObject,
                freeAccess: freeAccess,
                keyHintURL: URL(string: "https://modelstudio.console.alibabacloud.com/?tab=model#/api-key")
            )
        case .china:
            OpenAIEndpoint(
                displayName: "Qwen",
                keyPrefix: "qwen",
                baseURL: OpenAIEndpoint.url("https://dashscope.aliyuncs.com/compatible-mode/v1"),
                wireFormat: .chatCompletions,
                structuredOutputMode: .jsonObject,
                freeAccess: freeAccess,
                keyHintURL: URL(string: "https://bailian.console.aliyun.com/?tab=model#/api-key")
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
        case .qwen38Max:
            LLMModelInfo(modelID: "qwen3.8-max", displayName: "Qwen 3.8 Max", storageKey: "qwen38Max", generation: 3.8, pricing: LLMModelPricing(input: 12, output: 36, currency: .cny))
        case .qwen37Max:
            LLMModelInfo(modelID: "qwen3.7-max", displayName: "Qwen 3.7 Max", storageKey: "qwen37Max", generation: 3.7, pricing: LLMModelPricing(input: 12, output: 36, currency: .cny))
        case .qwen37Plus:
            LLMModelInfo(modelID: "qwen3.7-plus", displayName: "Qwen 3.7 Plus", storageKey: "qwen37Plus", generation: 3.7, pricing: LLMModelPricing(input: 2, output: 8, currency: .cny))
        case .qwen35Plus:
            LLMModelInfo(modelID: "qwen3.5-plus", displayName: "Qwen 3.5 Plus", storageKey: "qwen35Plus", generation: 3.5, pricing: LLMModelPricing(input: 0.8, output: 4.8, currency: .cny))
        case .qwenPlus:
            LLMModelInfo(modelID: "qwen-plus", displayName: "Qwen Plus (latest)", storageKey: "qwenPlus", pricing: LLMModelPricing(input: 0.8, output: 2, currency: .cny))
        case .qwen38Flash:
            LLMModelInfo(modelID: "qwen3.8-flash", displayName: "Qwen 3.8 Flash", storageKey: "qwen38Flash", generation: 3.8)
        case .qwen37Flash:
            LLMModelInfo(modelID: "qwen3.7-flash", displayName: "Qwen 3.7 Flash", storageKey: "qwen37Flash", generation: 3.7, pricing: LLMModelPricing(input: 0.2, output: 0.8, currency: .cny))
        case .qwen35Flash:
            LLMModelInfo(modelID: "qwen3.5-flash", displayName: "Qwen 3.5 Flash", storageKey: "qwen35Flash", generation: 3.5, pricing: LLMModelPricing(input: 0.2, output: 2, currency: .cny))
        case .qwenFlash:
            LLMModelInfo(modelID: "qwen-flash", displayName: "Qwen Flash (latest)", storageKey: "qwenFlash", pricing: LLMModelPricing(input: 0.15, output: 1.5, currency: .cny))
        case .qwenTurbo:
            LLMModelInfo(modelID: "qwen-turbo", displayName: "Qwen Turbo", storageKey: "qwenTurbo", pricing: LLMModelPricing(input: 0.3, output: 0.6, currency: .cny), supportsImageInput: false)
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias QwenClientConfiguration = OpenAICompatibleConfiguration<QwenModel>
public typealias QwenAPIClient = OpenAICompatibleClient<QwenModel>
