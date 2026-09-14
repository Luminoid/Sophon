//
//  AnthropicResponse.swift
//  SophonAnthropic
//
//  Decodable models for the Messages API response, its error envelope, and
//  the `GET /v1/models` listing.
//

import Foundation
import SophonCore

struct AnthropicResponse: Decodable {
    let content: [AnthropicResponseBlock]?
    /// "end_turn", "max_tokens", "stop_sequence", "tool_use", "refusal".
    let stopReason: String?

    private enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }

    /// All text blocks joined; thinking blocks are skipped.
    var extractedText: String? {
        let text = (content ?? []).filter { $0.type == "text" }.compactMap(\.text).joined()
        return text.isEmpty ? nil : text
    }

    var isTruncated: Bool { stopReason == "max_tokens" }
    var isRefusal: Bool { stopReason == "refusal" }
}

struct AnthropicResponseBlock: Decodable {
    let type: String?
    let text: String?
}

/// `{"type": "error", "error": {"type": "not_found_error", "message": "..."}}`
struct AnthropicErrorBody: Decodable {
    let error: AnthropicErrorPayload?

    static func parse(_ data: Data) -> AnthropicErrorPayload? {
        (try? JSONDecoder().decode(Self.self, from: data))?.error
    }
}

struct AnthropicErrorPayload: Decodable {
    let type: String?
    let message: String?

    /// A 404 whose message names the model, as opposed to a wrong base URL.
    var indicatesUnknownModel: Bool {
        guard type == "not_found_error" || type == "invalid_request_error" else { return false }
        return (message ?? "").lowercased().contains("model")
    }
}

struct AnthropicModelListResponse: Decodable {
    let data: [AnthropicModelListEntry]?
    let hasMore: Bool?
    let lastID: String?

    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case lastID = "last_id"
    }
}

struct AnthropicModelListEntry: Decodable {
    let id: String
    let displayName: String?
    let maxInputTokens: Int?
    let maxTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case maxInputTokens = "max_input_tokens"
        case maxTokens = "max_tokens"
    }

    var remoteModel: LLMRemoteModel {
        LLMRemoteModel(id: id, displayName: displayName, inputTokenLimit: maxInputTokens, outputTokenLimit: maxTokens)
    }
}
