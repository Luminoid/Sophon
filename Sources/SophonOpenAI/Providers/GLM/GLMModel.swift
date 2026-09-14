//
//  GLMModel.swift
//  SophonOpenAI
//
//  Zhipu / Z.ai GLM catalog and endpoints. Verified against docs.z.ai and
//  bigmodel.cn on 2026-09-13: glm-4.7-flash, glm-4.5-flash, and the vision
//  glm-4.6v-flash are free of charge (about 1 request per second); the GLM-5
//  line is paid. The China site (open.bigmodel.cn) and the international site
//  (api.z.ai) are separate accounts and keys. Prices are the international
//  list in USD. JSON mode only (`json_object`).
//

import Foundation
import SophonCore

public enum GLMModel: OpenAICompatibleModel {
    case glm53
    case glm53Flash
    case glm52
    case glm47
    case glm47FlashX
    case glm47Flash
    case glm45Flash
    case glm46V
    case glm46VFlash
    case custom(String)

    public static let allStandardCases: [Self] = [.glm53, .glm53Flash, .glm52, .glm47, .glm47FlashX, .glm47Flash, .glm45Flash, .glm46V, .glm46VFlash]
    public static let recommendedDefault: Self = .glm47Flash
    public static let recommendedFallback: Self = .glm45Flash

    public static let freeAccess: LLMProviderFreeAccess = .permanentTier(
        note: "glm-4.7-flash, glm-4.5-flash, and glm-4.6v-flash are free of charge at about 1 request per second; no card required."
    )

    public static func endpoint(region: OpenAIEndpointRegion) -> OpenAIEndpoint {
        switch region {
        case .international:
            OpenAIEndpoint(
                displayName: "GLM",
                keyPrefix: "glm",
                baseURL: OpenAIEndpoint.url("https://api.z.ai/api/paas/v4"),
                wireFormat: .chatCompletions,
                structuredOutputMode: .jsonObject,
                freeAccess: freeAccess,
                keyHintURL: URL(string: "https://z.ai/manage-apikey/apikey-list")
            )
        case .china:
            OpenAIEndpoint(
                displayName: "GLM",
                keyPrefix: "glm",
                baseURL: OpenAIEndpoint.url("https://open.bigmodel.cn/api/paas/v4"),
                wireFormat: .chatCompletions,
                structuredOutputMode: .jsonObject,
                freeAccess: freeAccess,
                keyHintURL: URL(string: "https://open.bigmodel.cn/usercenter/apikeys")
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
        case .glm53:
            LLMModelInfo(modelID: "glm-5.3", displayName: "GLM-5.3", storageKey: "glm53", generation: 5.3, pricing: LLMModelPricing(input: 1.40, output: 4.40), supportsImageInput: false)
        case .glm53Flash:
            LLMModelInfo(modelID: "glm-5.3-flash", displayName: "GLM-5.3 Flash", storageKey: "glm53Flash", generation: 5.3, pricing: LLMModelPricing(input: 0.15, output: 0.50))
        case .glm52:
            LLMModelInfo(modelID: "glm-5.2", displayName: "GLM-5.2", storageKey: "glm52", generation: 5.2, pricing: LLMModelPricing(input: 1.40, output: 4.40), supportsImageInput: false)
        case .glm47:
            LLMModelInfo(modelID: "glm-4.7", displayName: "GLM-4.7", storageKey: "glm47", generation: 4.7, pricing: LLMModelPricing(input: 0.60, output: 2.20), supportsImageInput: false)
        case .glm47FlashX:
            LLMModelInfo(
                modelID: "glm-4.7-flashx",
                displayName: "GLM-4.7 FlashX",
                storageKey: "glm47FlashX",
                generation: 4.7,
                pricing: LLMModelPricing(input: 0.07, output: 0.40),
                supportsImageInput: false
            )
        case .glm47Flash:
            LLMModelInfo(modelID: "glm-4.7-flash", displayName: "GLM-4.7 Flash (free)", storageKey: "glm47Flash", tier: .free, generation: 4.7, supportsImageInput: false, contextWindow: 200_000)
        case .glm45Flash:
            LLMModelInfo(modelID: "glm-4.5-flash", displayName: "GLM-4.5 Flash (free)", storageKey: "glm45Flash", tier: .free, generation: 4.5, supportsImageInput: false)
        case .glm46V:
            LLMModelInfo(modelID: "glm-4.6v", displayName: "GLM-4.6V", storageKey: "glm46V", generation: 4.6, pricing: LLMModelPricing(input: 0.30, output: 0.90))
        case .glm46VFlash:
            LLMModelInfo(modelID: "glm-4.6v-flash", displayName: "GLM-4.6V Flash (free)", storageKey: "glm46VFlash", tier: .free, generation: 4.6)
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias GLMClientConfiguration = OpenAICompatibleConfiguration<GLMModel>
public typealias GLMAPIClient = OpenAICompatibleClient<GLMModel>
