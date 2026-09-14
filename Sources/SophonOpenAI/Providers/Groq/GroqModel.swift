//
//  GroqModel.swift
//  SophonOpenAI
//
//  Groq catalog and endpoint. Verified against console.groq.com/docs on
//  2026-09-13: the production chat models below are all on the free plan
//  (gpt-oss-120b at 30 RPM, 1K RPD, 200K TPD; no card). None of them accept
//  image input.
//

import Foundation
import SophonCore

public enum GroqModel: OpenAICompatibleModel {
    case gptOSS120B
    case gptOSS20B
    case llama3370BVersatile
    case llama318BInstant
    case custom(String)

    public static let allStandardCases: [Self] = [.gptOSS120B, .gptOSS20B, .llama3370BVersatile, .llama318BInstant]
    public static let recommendedDefault: Self = .gptOSS120B
    public static let recommendedFallback: Self = .gptOSS20B

    public static let freeAccess: LLMProviderFreeAccess = .permanentTier(
        note: "Free plan on every production model (for example gpt-oss-120b at 30 requests and 8K tokens per minute, 1K requests and 200K tokens per day); no card required."
    )

    public static let defaultEndpoint = OpenAIEndpoint(
        displayName: "Groq",
        keyPrefix: "groq",
        baseURL: OpenAIEndpoint.url("https://api.groq.com/openai/v1"),
        wireFormat: .chatCompletions,
        structuredOutputMode: .jsonSchema,
        freeAccess: freeAccess,
        keyHintURL: URL(string: "https://console.groq.com/keys")
    )

    private static let contextWindow = 131_072

    public var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    public var info: LLMModelInfo {
        switch self {
        case .gptOSS120B:
            LLMModelInfo(modelID: "openai/gpt-oss-120b", displayName: "GPT-OSS 120B", storageKey: "gptOSS120B", tier: .free, supportsImageInput: false, contextWindow: Self.contextWindow)
        case .gptOSS20B:
            LLMModelInfo(modelID: "openai/gpt-oss-20b", displayName: "GPT-OSS 20B", storageKey: "gptOSS20B", tier: .free, supportsImageInput: false, contextWindow: Self.contextWindow)
        case .llama3370BVersatile:
            LLMModelInfo(
                modelID: "llama-3.3-70b-versatile",
                displayName: "Llama 3.3 70B Versatile",
                storageKey: "llama3370BVersatile",
                tier: .free,
                supportsImageInput: false,
                contextWindow: Self.contextWindow
            )
        case .llama318BInstant:
            LLMModelInfo(
                modelID: "llama-3.1-8b-instant",
                displayName: "Llama 3.1 8B Instant",
                storageKey: "llama318BInstant",
                tier: .free,
                supportsImageInput: false,
                contextWindow: Self.contextWindow
            )
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    public var successor: Self? { nil }
}

public typealias GroqClientConfiguration = OpenAICompatibleConfiguration<GroqModel>
public typealias GroqAPIClient = OpenAICompatibleClient<GroqModel>
