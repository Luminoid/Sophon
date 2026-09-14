//
//  AnthropicModelList.swift
//  SophonAnthropic
//
//  Decodable models for the `GET /v1/models` listing, mapped onto the
//  provider-neutral `LLMRemoteModel`.
//

import Foundation
import SophonCore

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
