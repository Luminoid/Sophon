//
//  AnthropicRequestModels.swift
//  SophonAnthropic
//
//  Codable models for the Messages API request body (`POST /v1/messages`).
//  Messages and parts are the provider-neutral `LLMMessage` / `LLMPart`;
//  system-role messages are lifted into the top-level `system` field (text
//  only: media in a system message is dropped), and messages with no parts
//  are skipped (an empty content array is a 400).
//

import Foundation
import SophonCore

/// Reasoning effort sent as `output_config.effort`; nil leaves the model's default.
public enum AnthropicEffort: String, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max
}

struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let temperature: Double?
    let outputConfig: AnthropicOutputConfig?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(system, forKey: .system)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(outputConfig, forKey: .outputConfig)
    }

    private enum CodingKeys: String, CodingKey {
        case model, system, messages, temperature
        case maxTokens = "max_tokens"
        case outputConfig = "output_config"
    }

    /// Maps neutral messages onto the wire: system parts become `system`, the
    /// rest alternate `user` / `assistant` with typed content blocks.
    static func make(
        modelID: String,
        messages: [LLMMessage],
        maxTokens: Int,
        temperature: Double?,
        schema: LLMSchema?,
        effort: AnthropicEffort?
    ) -> Self {
        let system = messages.filter { $0.role == .system }.flatMap(\.parts).compactMap(\.text).joined(separator: "\n\n")
        let turns = messages.filter { $0.role != .system && !$0.parts.isEmpty }.map { message in
            AnthropicMessage(role: message.role == .assistant ? "assistant" : "user", content: message.parts.map(AnthropicContentBlock.init))
        }
        let outputConfig: AnthropicOutputConfig? = (schema != nil || effort != nil)
            ? AnthropicOutputConfig(format: schema?.encoded(as: .jsonSchema), effort: effort?.rawValue)
            : nil
        return Self(
            model: modelID,
            maxTokens: maxTokens,
            system: system.isEmpty ? nil : system,
            messages: turns,
            temperature: temperature,
            outputConfig: outputConfig
        )
    }
}

struct AnthropicMessage: Encodable {
    let role: String
    let content: [AnthropicContentBlock]
}

enum AnthropicContentBlock: Encodable {
    case text(String)
    /// `{"type": "image", "source": {"type": "base64", "media_type": ..., "data": ...}}`
    case image(mediaType: String, data: String)
    /// `{"type": "document", "source": {"type": "base64", "media_type": ..., "data": ...}}` (PDF).
    case document(mediaType: String, data: String)
    /// `{"type": "document", "source": {"type": "text", "media_type": "text/plain", "data": ...}}`:
    /// the API takes plain-text documents decoded, not base64.
    case textDocument(String)

    init(_ part: LLMPart) {
        switch part {
        case let .text(text):
            self = .text(text)
        case let .inlineData(mimeType, data):
            if mimeType.hasPrefix("image/") {
                self = .image(mediaType: mimeType, data: data)
            } else if mimeType == "text/plain" {
                let decoded = Data(base64Encoded: data).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                self = .textDocument(decoded)
            } else {
                self = .document(mediaType: mimeType, data: data)
            }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .image(mediaType, data):
            try container.encode("image", forKey: .type)
            try container.encode(AnthropicBase64Source(mediaType: mediaType, data: data), forKey: .source)
        case let .document(mediaType, data):
            try container.encode("document", forKey: .type)
            try container.encode(AnthropicBase64Source(mediaType: mediaType, data: data), forKey: .source)
        case let .textDocument(text):
            try container.encode("document", forKey: .type)
            try container.encode(AnthropicTextSource(data: text), forKey: .source)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, source
    }
}

struct AnthropicBase64Source: Encodable {
    let mediaType: String
    let data: String

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("base64", forKey: .type)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encode(data, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case type, data
        case mediaType = "media_type"
    }
}

struct AnthropicTextSource: Encodable {
    let data: String

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("text", forKey: .type)
        try container.encode("text/plain", forKey: .mediaType)
        try container.encode(data, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case type, data
        case mediaType = "media_type"
    }
}

/// `output_config`: structured-output format and/or reasoning effort.
struct AnthropicOutputConfig: Encodable {
    let format: LLMSchemaDocument?
    let effort: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let format {
            try container.encode(AnthropicJSONSchemaFormat(schema: format), forKey: .format)
        }
        try container.encodeIfPresent(effort, forKey: .effort)
    }

    private enum CodingKeys: String, CodingKey {
        case format, effort
    }
}

/// `{"type": "json_schema", "schema": {...}}`
struct AnthropicJSONSchemaFormat: Encodable {
    let schema: LLMSchemaDocument

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("json_schema", forKey: .type)
        try container.encode(schema, forKey: .schema)
    }

    private enum CodingKeys: String, CodingKey {
        case type, schema
    }
}
