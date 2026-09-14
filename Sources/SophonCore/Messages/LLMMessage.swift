//
//  LLMMessage.swift
//  SophonCore
//
//  Provider-neutral message and part types. Provider targets map them onto
//  their wire formats (Gemini `contents`, OpenAI `messages`/`input`, Anthropic
//  `messages` + `system`). Both types are `Encodable` in the plain JSON shape
//  Sophon 0.1 and 0.2 produced (`{"text": ...}` / `{"inlineData": {...}}`,
//  `{"role": ..., "parts": [...]}`), so consumers that serialize them directly
//  keep working; the provider DTOs decide the actual wire form.
//

import Foundation

/// Conversation role. Providers spell these differently on the wire (Gemini
/// says "model" for the assistant turn); the neutral set is what callers use.
public enum LLMRole: String, Sendable, Encodable {
    case user
    case assistant
    case system

    /// Maps a provider-flavored role name onto the neutral set: "user",
    /// "assistant", "system", and Gemini's "model" (assistant). Unknown names
    /// return nil.
    public init?(providerRole: String) {
        switch providerRole.lowercased() {
        case "user": self = .user
        case "assistant", "model": self = .assistant
        case "system": self = .system
        default: return nil
        }
    }
}

/// One piece of a message: text, or base64-encoded inline media.
public enum LLMPart: Sendable, Equatable, Encodable {
    case text(String)
    /// Base64-encoded media (image, PDF) sent inline. Media parts go before the
    /// instruction text so the model reads the prompt in the context of the
    /// already-ingested documents.
    case inlineData(mimeType: String, data: String)

    public var isMedia: Bool {
        if case .inlineData = self { return true }
        return false
    }

    /// The MIME type of an inline-data part; nil for text.
    public var mimeType: String? {
        if case let .inlineData(mimeType, _) = self { return mimeType }
        return nil
    }

    /// The text of a text part; nil for media.
    public var text: String? {
        if case let .text(text) = self { return text }
        return nil
    }

    /// `{"text": ...}` or `{"inlineData": {"mimeType": ..., "data": ...}}`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(text):
            try container.encode(["text": text])
        case let .inlineData(mimeType, data):
            try container.encode(InlineDataPayload(inlineData: InlineDataPayload.Content(mimeType: mimeType, data: data)))
        }
    }
}

private struct InlineDataPayload: Encodable {
    let inlineData: Content

    struct Content: Encodable {
        let mimeType: String
        let data: String
    }
}

/// A role-tagged message. A nil role means "the single user turn" for
/// providers that infer it (Gemini single-turn requests).
public struct LLMMessage: Sendable, Equatable, Encodable {
    public let role: LLMRole?
    public let parts: [LLMPart]

    public init(parts: [LLMPart], role: LLMRole? = nil) {
        self.role = role
        self.parts = parts
    }

    /// Provider-flavored role names ("user", "model", "assistant", "system"),
    /// as the Gemini client accepted since 0.1. Unknown names leave the role nil.
    public init(parts: [LLMPart], role: String) {
        self.init(parts: parts, role: LLMRole(providerRole: role))
    }

    /// `{"role": "user", "parts": [...]}`; the role is omitted when nil.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encode(parts, forKey: .parts)
    }

    private enum CodingKeys: String, CodingKey {
        case role, parts
    }
}
