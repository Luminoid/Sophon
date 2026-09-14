//
//  OpenAIRequestPlan.swift
//  SophonOpenAI
//
//  The resolved inputs of a request body and the body itself in either wire
//  format; `OpenAIRequestBodies` maps one onto the other.
//

import Foundation
import SophonCore

/// Everything a request body needs, resolved on the client's actor so encoding
/// can run off-main.
struct OpenAIRequestPlan {
    let endpoint: OpenAIEndpoint
    let modelID: String
    let messages: [LLMMessage]
    /// nil when the model does not accept sampling parameters.
    let temperature: Double?
    let maxOutputTokens: Int
    let schema: LLMSchema?
}

enum OpenAIRequestBody: Encodable {
    case chat(OpenAIChatRequest)
    case responses(OpenAIResponsesRequest)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .chat(request): try container.encode(request)
        case let .responses(request): try container.encode(request)
        }
    }
}
