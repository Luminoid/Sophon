//
//  OpenAIModelList.swift
//  SophonOpenAI
//
//  Decodable model for `GET /models`, mapped onto `LLMRemoteModel`. Every
//  OpenAI-compatible provider serves the `{"data": [{"id": ...}]}` shape;
//  gateways such as OpenRouter add a display name and context length.
//

import Foundation
import SophonCore

struct OpenAIModelListResponse: Decodable {
    let data: [OpenAIModelListEntry]?
}

struct OpenAIModelListEntry: Decodable {
    let id: String
    let name: String?
    let contextLength: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
    }

    var remoteModel: LLMRemoteModel {
        LLMRemoteModel(id: id, displayName: name, inputTokenLimit: contextLength)
    }
}
