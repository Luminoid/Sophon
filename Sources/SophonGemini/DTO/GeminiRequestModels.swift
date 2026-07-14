//
//  GeminiRequestModels.swift
//  SophonGemini
//
//  Codable models for the Gemini REST API request body.
//

import Foundation

public struct GeminiRequest: Encodable, Sendable {
    public let contents: [GeminiContent]
    public let generationConfig: GeminiGenerationConfig

    public init(contents: [GeminiContent], generationConfig: GeminiGenerationConfig) {
        self.contents = contents
        self.generationConfig = generationConfig
    }
}

public struct GeminiContent: Encodable, Sendable {
    public let role: String?
    public let parts: [GeminiPart]

    public init(parts: [GeminiPart], role: String? = nil) {
        self.role = role
        self.parts = parts
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let role { try container.encode(role, forKey: .role) }
        try container.encode(parts, forKey: .parts)
    }

    private enum CodingKeys: String, CodingKey {
        case role, parts
    }
}

public struct GeminiGenerationConfig: Encodable, Sendable {
    public let responseMimeType: String
    public let temperature: Double
    public let responseSchema: GeminiSchema?

    public init(responseMimeType: String, temperature: Double, responseSchema: GeminiSchema? = nil) {
        self.responseMimeType = responseMimeType
        self.temperature = temperature
        self.responseSchema = responseSchema
    }

    enum CodingKeys: String, CodingKey {
        case responseMimeType = "response_mime_type"
        case temperature
        case responseSchema = "response_schema"
    }
}

public enum GeminiPart: Encodable, Sendable {
    case text(String)
    /// Base64-encoded media (image, PDF) sent inline. Media parts go before the
    /// instruction text so the model reads the prompt in the context of the
    /// already-ingested documents.
    case inlineData(mimeType: String, data: String)

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(text):
            try container.encode(["text": text])
        case let .inlineData(mimeType, data):
            try container.encode(InlineDataPayload(inlineData: InlineDataPayload.Content(mimeType: mimeType, data: data)))
        }
    }
}

private struct InlineDataPayload: Encodable {
    let inlineData: Content

    struct Content: Encodable {
        let mimeType: String
        let data: String
    }
}
