//
//  OpenAIEndpoint.swift
//  SophonOpenAI
//
//  Where an OpenAI-compatible client talks to and how: base URL, wire format
//  (OpenAI's Responses API or the Chat Completions dialect every compatible
//  provider implements), structured-output mode, auth header shape, and the
//  provider's free-access terms. Presets live on each provider's model catalog.
//

import Foundation
import SophonCore

public enum OpenAIWireFormat: Sendable, Equatable {
    /// `POST {baseURL}/responses`, OpenAI's current API.
    case responses
    /// `POST {baseURL}/chat/completions`, implemented by OpenAI and every compatible provider.
    case chatCompletions

    var generationPath: String {
        switch self {
        case .responses: "responses"
        case .chatCompletions: "chat/completions"
        }
    }
}

public enum OpenAIStructuredOutputMode: Sendable, Equatable {
    /// Strict `json_schema` response format: the provider enforces the schema.
    case jsonSchema
    /// `json_object` response format with the schema appended to the prompt,
    /// for providers that only guarantee syntactically valid JSON.
    case jsonObject
}

/// Which parameter carries the output-token ceiling on Chat Completions.
public enum OpenAIMaxTokensField: Sendable, Equatable {
    /// `max_completion_tokens` (required by OpenAI's reasoning models).
    case maxCompletionTokens
    /// `max_tokens` (the classic field most compatible providers accept).
    case maxTokens
}

public enum OpenAIEndpointRegion: String, Sendable, Equatable {
    case international
    case china
}

public struct OpenAIEndpoint: Sendable, Equatable {
    public var displayName: String
    /// Short identifier that derives the default UserDefaults keys
    /// (`ai.<keyPrefix>Enabled` / `Model` / `CustomModel`) and log labels.
    /// Must be unique per provider. Region variants of one provider share it
    /// on purpose, so a stored model selection and the enabled toggle survive
    /// a region switch; their API keys do not, so give each region its own
    /// `keychainAccount` (the China and international consoles issue
    /// different keys).
    public var keyPrefix: String
    /// Base URL without a trailing slash, e.g. `https://api.groq.com/openai/v1`.
    public var baseURL: URL
    public var wireFormat: OpenAIWireFormat
    public var structuredOutputMode: OpenAIStructuredOutputMode
    public var maxTokensField: OpenAIMaxTokensField
    public var authorizationHeaderField: String
    public var authorizationValuePrefix: String
    /// Headers added to every request (provider-specific attribution, versions).
    public var extraHeaders: [String: String]
    public var freeAccess: LLMProviderFreeAccess
    /// Where the user gets an API key, for settings hints.
    public var keyHintURL: URL?

    public init(
        displayName: String,
        keyPrefix: String,
        baseURL: URL,
        wireFormat: OpenAIWireFormat = .chatCompletions,
        structuredOutputMode: OpenAIStructuredOutputMode = .jsonObject,
        maxTokensField: OpenAIMaxTokensField = .maxTokens,
        authorizationHeaderField: String = "Authorization",
        authorizationValuePrefix: String = "Bearer ",
        extraHeaders: [String: String] = [:],
        freeAccess: LLMProviderFreeAccess = .none,
        keyHintURL: URL? = nil
    ) {
        self.displayName = displayName
        self.keyPrefix = keyPrefix
        self.baseURL = baseURL
        self.wireFormat = wireFormat
        self.structuredOutputMode = structuredOutputMode
        self.maxTokensField = maxTokensField
        self.authorizationHeaderField = authorizationHeaderField
        self.authorizationValuePrefix = authorizationValuePrefix
        self.extraHeaders = extraHeaders
        self.freeAccess = freeAccess
        self.keyHintURL = keyHintURL
    }

    public var enabledDefaultsKey: String { "ai.\(keyPrefix)Enabled" }
    public var modelDefaultsKey: String { "ai.\(keyPrefix)Model" }
    public var customModelDefaultsKey: String { "ai.\(keyPrefix)CustomModel" }

    /// `baseURL` plus a relative path, keeping any base path segment
    /// (`/openai/v1`, `/api/paas/v4`) intact.
    public func url(path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    /// Builds a URL from a literal, trapping on malformed catalog data so a
    /// broken preset fails at first use rather than at request time.
    static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Malformed endpoint URL literal: \(string)")
        }
        return url
    }
}
