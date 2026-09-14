//
//  AnthropicResponse.swift
//  SophonAnthropic
//
//  Decodable models for the Messages API response.
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
