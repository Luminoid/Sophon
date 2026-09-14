//
//  GeminiRequestModels.swift
//  SophonGemini
//
//  Codable models for the Gemini REST API request body. Messages and parts are
//  the provider-neutral `LLMMessage` / `LLMPart` (aliased `GeminiContent` /
//  `GeminiPart` in `GeminiCompatibility.swift`); parts already encode in
//  Gemini's `{"text"}` / `{"inlineData"}` shape, and this file maps roles onto
//  `user` / `model` and lifts system messages into `system_instruction`.
//

import Foundation
import SophonCore

public struct GeminiRequest: Encodable, Sendable {
    public let contents: [GeminiContent]
    public let generationConfig: GeminiGenerationConfig

    public init(contents: [GeminiContent], generationConfig: GeminiGenerationConfig) {
        self.contents = contents
        self.generationConfig = generationConfig
    }

    /// System-role messages are lifted into `system_instruction`; the rest
    /// become `contents` with Gemini's `user` / `model` role names.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let systemParts = contents.filter { $0.role == .system }.flatMap(\.parts)
        let turns = contents.filter { $0.role != .system }
        try container.encode(turns.map { GeminiContentPayload(message: $0) }, forKey: .contents)
        if !systemParts.isEmpty {
            try container.encode(GeminiContentPayload(message: LLMMessage(parts: systemParts)), forKey: .systemInstruction)
        }
        try container.encode(generationConfig, forKey: .generationConfig)
    }

    private enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
        case generationConfig
    }
}

public struct GeminiGenerationConfig: Encodable, Sendable {
    public let responseMimeType: String
    public let temperature: Double
    public let responseSchema: GeminiSchema?

    public init(responseMimeType: String, temperature: Double, responseSchema: GeminiSchema? = nil) {
        self.responseMimeType = responseMimeType
        self.temperature = temperature
        self.responseSchema = responseSchema
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(responseMimeType, forKey: .responseMimeType)
        try container.encode(temperature, forKey: .temperature)
        try container.encodeIfPresent(responseSchema?.encoded(as: .openAPI), forKey: .responseSchema)
    }

    private enum CodingKeys: String, CodingKey {
        case responseMimeType = "response_mime_type"
        case temperature
        case responseSchema = "response_schema"
    }
}

/// Gemini wire form of a message: `{"role": "user" | "model", "parts": [...]}`.
struct GeminiContentPayload: Encodable {
    let message: LLMMessage

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let role = message.role {
            try container.encode(Self.wireRole(role), forKey: .role)
        }
        try container.encode(message.parts, forKey: .parts)
    }

    static func wireRole(_ role: LLMRole) -> String {
        switch role {
        case .user, .system: "user"
        case .assistant: "model"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case role, parts
    }
}
