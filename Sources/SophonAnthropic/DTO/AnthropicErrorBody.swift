//
//  AnthropicErrorBody.swift
//  SophonAnthropic
//
//  Decoding of the Messages API error envelope and the two body heuristics
//  the status mapping needs: a 404 that names the model, and a 400 that
//  reports an exhausted credit balance.
//

import Foundation

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

    /// A 404 whose message names the model ("model: claude-x"), as opposed to
    /// a wrong base URL. Only `not_found_error` qualifies: a 400
    /// `invalid_request_error` that mentions the model ("temperature is not
    /// supported by this model") is a request problem, not a retired model.
    var indicatesUnknownModel: Bool {
        guard type == "not_found_error" else { return false }
        return (message ?? "").lowercased().contains("model")
    }

    /// The API reports an empty credit balance as a 400 `invalid_request_error`.
    var indicatesInsufficientCredit: Bool {
        let lowered = (message ?? "").lowercased()
        return lowered.contains("credit balance") || lowered.contains("billing")
    }
}
