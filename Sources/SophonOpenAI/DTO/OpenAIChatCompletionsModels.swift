//
//  OpenAIChatCompletionsModels.swift
//  SophonOpenAI
//
//  Codable models for the Chat Completions wire format
//  (`POST /chat/completions`), the dialect every OpenAI-compatible provider
//  implements.
//

import Foundation
import SophonCore

struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let maxCompletionTokens: Int?
    let responseFormat: OpenAIResponseFormat?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(maxCompletionTokens, forKey: .maxCompletionTokens)
        try container.encodeIfPresent(responseFormat, forKey: .responseFormat)
    }

    private enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
        case responseFormat = "response_format"
    }
}

/// A chat message. Text-only content encodes as a plain string (the most widely
/// accepted form); mixed content encodes as an array of typed parts.
struct OpenAIChatMessage: Encodable {
    let role: String
    let parts: [OpenAIChatContentPart]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        let texts = parts.compactMap(\.plainText)
        if texts.count == parts.count {
            try container.encode(texts.joined(separator: "\n\n"), forKey: .content)
        } else {
            try container.encode(parts, forKey: .content)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case role, content
    }
}

enum OpenAIChatContentPart: Encodable {
    case text(String)
    /// `{"type": "image_url", "image_url": {"url": "data:<mime>;base64,..."}}`
    case imageURL(String)
    /// `{"type": "file", "file": {"filename": ..., "file_data": "data:...;base64,..."}}`
    case file(filename: String, dataURL: String)

    var plainText: String? {
        if case let .text(text) = self { return text }
        return nil
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .imageURL(url):
            try container.encode("image_url", forKey: .type)
            try container.encode(["url": url], forKey: .imageURL)
        case let .file(filename, dataURL):
            try container.encode("file", forKey: .type)
            try container.encode(["filename": filename, "file_data": dataURL], forKey: .file)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, file
        case imageURL = "image_url"
    }
}

enum OpenAIResponseFormat: Encodable {
    /// `{"type": "json_object"}`
    case jsonObject
    /// `{"type": "json_schema", "json_schema": {"name": "response", "schema": ..., "strict": true}}`
    case jsonSchema(LLMSchemaDocument)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .jsonObject:
            try container.encode("json_object", forKey: .type)
        case let .jsonSchema(document):
            try container.encode("json_schema", forKey: .type)
            try container.encode(OpenAIJSONSchemaEnvelope(schema: document), forKey: .jsonSchema)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

/// The `json_schema` envelope shared by both wire formats.
struct OpenAIJSONSchemaEnvelope: Encodable {
    static let name = "response"

    let schema: LLMSchemaDocument

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.name, forKey: .name)
        try container.encode(schema, forKey: .schema)
        try container.encode(true, forKey: .strict)
    }

    private enum CodingKeys: String, CodingKey {
        case name, schema, strict
    }
}

// MARK: - Response

struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChatChoice]?

    /// The first choice's text, joined from a string or array `content`.
    var extractedText: String? {
        guard let text = choices?.first?.message?.content, !text.isEmpty else { return nil }
        return text
    }

    var refusal: String? {
        guard let refusal = choices?.first?.message?.refusal, !refusal.isEmpty else { return nil }
        return refusal
    }

    var finishReason: String? {
        choices?.first?.finishReason
    }

    var isTruncated: Bool { finishReason == "length" }
    var isFiltered: Bool { finishReason == "content_filter" }
}

struct OpenAIChatChoice: Decodable {
    let message: OpenAIChatResponseMessage?
    let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIChatResponseMessage: Decodable {
    let content: String?
    let refusal: String?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refusal = try container.decodeIfPresent(String.self, forKey: .refusal)
        // A few providers return `content` as an array of text parts.
        if let text = try? container.decodeIfPresent(String.self, forKey: .content) {
            content = text
        } else if let parts = try? container.decodeIfPresent([OpenAIChatTextPart].self, forKey: .content) {
            content = parts.compactMap(\.text).joined()
        } else {
            content = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case content, refusal
    }
}

struct OpenAIChatTextPart: Decodable {
    let text: String?
}
