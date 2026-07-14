//
//  GeminiResponse.swift
//  SophonGemini
//
//  Codable models for the Gemini REST API response body, including block-reason
//  and truncation surfacing.
//

import Foundation

public struct GeminiResponse: Decodable, Sendable {
    public let candidates: [GeminiCandidate]?
    public let promptFeedback: GeminiPromptFeedback?
    public let error: GeminiAPIError?

    public struct GeminiCandidate: Decodable, Sendable {
        public let content: GeminiResponseContent?
        /// "STOP", "MAX_TOKENS", "SAFETY", "RECITATION", etc. Absent on older/partial responses.
        public let finishReason: String?
    }

    public struct GeminiResponseContent: Decodable, Sendable {
        public let parts: [GeminiResponsePart]?
    }

    public struct GeminiResponsePart: Decodable, Sendable {
        public let text: String?
        /// True on "thought summary" parts thinking models can emit; excluded
        /// from `extractedText`.
        public let thought: Bool?
    }

    /// Present when Gemini blocks the prompt itself (before generating any candidate).
    public struct GeminiPromptFeedback: Decodable, Sendable {
        public let blockReason: String?
    }

    public struct GeminiAPIError: Decodable, Sendable {
        public let message: String?
        public let code: Int?
    }

    /// Extract the text content from the first candidate, joining all of its
    /// non-thought parts: long responses can legitimately arrive split across
    /// several parts, and reading only the first would silently drop the rest.
    public var extractedText: String? {
        guard let parts = candidates?.first?.content?.parts else { return nil }
        let text = parts.filter { $0.thought != true }.compactMap(\.text).joined()
        return text.isEmpty ? nil : text
    }

    /// A safety/recitation block reason if the prompt or first candidate was refused, else nil.
    public var blockReason: String? {
        if let promptBlock = promptFeedback?.blockReason, !promptBlock.isEmpty {
            return promptBlock
        }
        if let finish = candidates?.first?.finishReason, Self.blockingFinishReasons.contains(finish) {
            return finish
        }
        return nil
    }

    /// True when the first candidate was cut off by the output-token limit.
    public var isTruncated: Bool {
        candidates?.first?.finishReason == "MAX_TOKENS"
    }

    private static let blockingFinishReasons: Set<String> = ["SAFETY", "RECITATION", "BLOCKLIST", "PROHIBITED_CONTENT", "SPII"]
}
