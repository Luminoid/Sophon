//
//  OpenAIResponsesModels.swift
//  SophonOpenAI
//
//  Codable models for OpenAI's Responses API (`POST /responses`).
//

import Foundation
import SophonCore

struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: [OpenAIResponsesInputMessage]
    /// System prompt; the Responses API takes it top-level.
    let instructions: String?
    let temperature: Double?
    let maxOutputTokens: Int?
    let textFormat: OpenAIResponsesTextFormat?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(input, forKey: .input)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxOutputTokens, forKey: .maxOutputTokens)
        if let textFormat {
            try container.encode(["format": textFormat], forKey: .text)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case model, input, instructions, temperature, text
        case maxOutputTokens = "max_output_tokens"
    }
}

struct OpenAIResponsesInputMessage: Encodable {
    let role: String
    let content: [OpenAIResponsesContentPart]
}

enum OpenAIResponsesContentPart: Encodable {
    case inputText(String)
    /// `{"type": "input_image", "image_url": "data:<mime>;base64,..."}`
    case inputImage(dataURL: String)
    /// `{"type": "input_file", "filename": ..., "file_data": "data:...;base64,..."}`
    case inputFile(filename: String, dataURL: String)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .inputText(text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .inputImage(dataURL):
            try container.encode("input_image", forKey: .type)
            try container.encode(dataURL, forKey: .imageURL)
        case let .inputFile(filename, dataURL):
            try container.encode("input_file", forKey: .type)
            try container.encode(filename, forKey: .filename)
            try container.encode(dataURL, forKey: .fileData)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, filename
        case imageURL = "image_url"
        case fileData = "file_data"
    }
}

enum OpenAIResponsesTextFormat: Encodable {
    /// `{"type": "json_object"}`
    case jsonObject
    /// `{"type": "json_schema", "name": "response", "schema": ..., "strict": true}`
    case jsonSchema(LLMSchemaDocument)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .jsonObject:
            try container.encode("json_object", forKey: .type)
        case let .jsonSchema(document):
            try container.encode("json_schema", forKey: .type)
            try container.encode(OpenAIJSONSchemaEnvelope.name, forKey: .name)
            try container.encode(document, forKey: .schema)
            try container.encode(true, forKey: .strict)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, name, schema, strict
    }
}

// MARK: - Response

struct OpenAIResponsesResponse: Decodable {
    let output: [OpenAIResponsesOutputItem]?
    let status: String?
    let incompleteDetails: OpenAIResponsesIncompleteDetails?

    private enum CodingKeys: String, CodingKey {
        case output, status
        case incompleteDetails = "incomplete_details"
    }

    private var messageContent: [OpenAIResponsesContentItem] {
        (output ?? []).filter { $0.type == "message" }.flatMap { $0.content ?? [] }
    }

    /// All `output_text` items of the message outputs, joined.
    var extractedText: String? {
        let text = messageContent.filter { $0.type == "output_text" }.compactMap(\.text).joined()
        return text.isEmpty ? nil : text
    }

    var refusal: String? {
        messageContent.first { $0.type == "refusal" }?.refusal
    }

    var isTruncated: Bool {
        status == "incomplete" && incompleteDetails?.reason == "max_output_tokens"
    }

    var isFiltered: Bool {
        incompleteDetails?.reason == "content_filter"
    }
}

struct OpenAIResponsesOutputItem: Decodable {
    let type: String?
    let content: [OpenAIResponsesContentItem]?
}

struct OpenAIResponsesContentItem: Decodable {
    let type: String?
    let text: String?
    let refusal: String?
}

struct OpenAIResponsesIncompleteDetails: Decodable {
    let reason: String?
}
