//
//  OpenAIErrorBody.swift
//  SophonOpenAI
//
//  Lenient decoding of error bodies across OpenAI-compatible providers, which
//  agree on the idea (`message`, `type`, `code`) but not on the shape: most
//  wrap it in `error`, Mistral sends it flat, and `code` is a string on some
//  providers and a number on others.
//

import Foundation

struct OpenAIErrorPayload: Decodable {
    let message: String?
    let type: String?
    let code: String?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        if let string = try? container.decodeIfPresent(String.self, forKey: .code) {
            code = string
        } else if let number = try? container.decodeIfPresent(Int.self, forKey: .code) {
            code = String(number)
        } else {
            code = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case message, type, code
    }

    /// Codes and types providers use for an unknown model (OpenAI, Groq,
    /// OpenRouter, Mistral, Zhipu, Doubao), plus a message heuristic for the
    /// ones that only say so in prose, in English or Chinese.
    private static let unknownModelMarkers: Set<String> = [
        "model_not_found", "modelnotfound", "modelnotopen", "invalid_model", "1211",
    ]

    private static let unknownModelPhrases = [
        "model not found", "not found", "not exist", "does not exist", "no such model", "invalid model", "unknown model", "模型不存在",
    ]

    var indicatesUnknownModel: Bool {
        for marker in [code, type].compactMap({ $0?.lowercased() }) where Self.unknownModelMarkers.contains(marker) {
            return true
        }
        guard let message else { return false }
        let lowered = message.lowercased()
        guard lowered.contains("model") || lowered.contains("模型") else { return false }
        return Self.unknownModelPhrases.contains { lowered.contains($0) }
    }

    var indicatesInsufficientQuota: Bool {
        let lowered = (code ?? "").lowercased()
        return lowered.contains("insufficient_quota") || lowered.contains("insufficient_credits") || lowered.contains("billing")
            || lowered == "1113" // Zhipu: account balance exhausted
    }
}

enum OpenAIErrorBody {
    private struct Wrapped: Decodable {
        let error: OpenAIErrorPayload
    }

    /// The error payload from a wrapped (`{"error": {...}}`) or flat body, if any.
    static func parse(_ data: Data) -> OpenAIErrorPayload? {
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(Wrapped.self, from: data) {
            return wrapped.error
        }
        if let flat = try? decoder.decode(OpenAIErrorPayload.self, from: data), flat.message != nil || flat.code != nil {
            return flat
        }
        return nil
    }
}
