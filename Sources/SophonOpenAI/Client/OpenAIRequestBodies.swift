//
//  OpenAIRequestBodies.swift
//  SophonOpenAI
//
//  Maps provider-neutral messages onto the two wire formats, including the
//  structured-output mode: strict `json_schema`, or `json_object` with the
//  schema spelled out in the prompt for providers that lack schema enforcement.
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

enum OpenAIRequestBodies {
    static let jsonObjectInstruction = "Respond only with a JSON object that matches this JSON schema:"

    static func body(for plan: OpenAIRequestPlan) throws -> OpenAIRequestBody {
        let messages = try messagesForStructuredMode(plan)
        switch plan.endpoint.wireFormat {
        case .chatCompletions:
            return .chat(chatRequest(plan, messages: messages))
        case .responses:
            return .responses(responsesRequest(plan, messages: messages))
        }
    }

    // MARK: - Structured-output mode

    /// In `.jsonObject` mode the provider only guarantees valid JSON, so the
    /// schema rides in the prompt: appended to the last user text part.
    private static func messagesForStructuredMode(_ plan: OpenAIRequestPlan) throws -> [LLMMessage] {
        guard let schema = plan.schema, plan.endpoint.structuredOutputMode == .jsonObject else {
            return plan.messages
        }
        let schemaJSON = try String(bytes: JSONEncoder().encode(schema.encoded(as: .jsonSchema)), encoding: .utf8) ?? "{}"
        let note = "\n\n\(jsonObjectInstruction)\n\(schemaJSON)"
        var messages = plan.messages
        if let index = messages.lastIndex(where: { $0.role == .user || $0.role == nil }) {
            let message = messages[index]
            var parts = message.parts
            if let textIndex = parts.lastIndex(where: { $0.text != nil }), let text = parts[textIndex].text {
                parts[textIndex] = .text(text + note)
            } else {
                parts.append(.text(String(note.dropFirst(2))))
            }
            messages[index] = LLMMessage(parts: parts, role: message.role)
        } else {
            messages.append(LLMMessage(parts: [.text(String(note.dropFirst(2)))], role: .user))
        }
        return messages
    }

    // MARK: - Chat Completions

    private static func chatRequest(_ plan: OpenAIRequestPlan, messages: [LLMMessage]) -> OpenAIChatRequest {
        OpenAIChatRequest(
            model: plan.modelID,
            messages: messages.map { message in
                OpenAIChatMessage(role: chatRole(message.role), parts: message.parts.map(chatPart))
            },
            temperature: plan.temperature,
            maxTokens: plan.endpoint.maxTokensField == .maxTokens ? plan.maxOutputTokens : nil,
            maxCompletionTokens: plan.endpoint.maxTokensField == .maxCompletionTokens ? plan.maxOutputTokens : nil,
            responseFormat: responseFormat(plan)
        )
    }

    private static func chatRole(_ role: LLMRole?) -> String {
        switch role {
        case .assistant: "assistant"
        case .system: "system"
        case .user, nil: "user"
        }
    }

    private static func chatPart(_ part: LLMPart) -> OpenAIChatContentPart {
        switch part {
        case let .text(text):
            .text(text)
        case let .inlineData(mimeType, data):
            if mimeType.hasPrefix("image/") {
                .imageURL(dataURL(mimeType: mimeType, data: data))
            } else {
                .file(filename: filename(for: mimeType), dataURL: dataURL(mimeType: mimeType, data: data))
            }
        }
    }

    private static func responseFormat(_ plan: OpenAIRequestPlan) -> OpenAIResponseFormat? {
        guard let schema = plan.schema else { return nil }
        switch plan.endpoint.structuredOutputMode {
        case .jsonSchema: return .jsonSchema(schema.encoded(as: .jsonSchema))
        case .jsonObject: return .jsonObject
        }
    }

    // MARK: - Responses API

    private static func responsesRequest(_ plan: OpenAIRequestPlan, messages: [LLMMessage]) -> OpenAIResponsesRequest {
        let instructions = messages.filter { $0.role == .system }.flatMap(\.parts).compactMap(\.text).joined(separator: "\n\n")
        let turns = messages.filter { $0.role != .system }
        return OpenAIResponsesRequest(
            model: plan.modelID,
            input: turns.map { message in
                OpenAIResponsesInputMessage(role: message.role == .assistant ? "assistant" : "user", content: message.parts.map(responsesPart))
            },
            instructions: instructions.isEmpty ? nil : instructions,
            temperature: plan.temperature,
            maxOutputTokens: plan.maxOutputTokens,
            textFormat: textFormat(plan)
        )
    }

    private static func responsesPart(_ part: LLMPart) -> OpenAIResponsesContentPart {
        switch part {
        case let .text(text):
            .inputText(text)
        case let .inlineData(mimeType, data):
            if mimeType.hasPrefix("image/") {
                .inputImage(dataURL: dataURL(mimeType: mimeType, data: data))
            } else {
                .inputFile(filename: filename(for: mimeType), dataURL: dataURL(mimeType: mimeType, data: data))
            }
        }
    }

    private static func textFormat(_ plan: OpenAIRequestPlan) -> OpenAIResponsesTextFormat? {
        guard let schema = plan.schema else { return nil }
        switch plan.endpoint.structuredOutputMode {
        case .jsonSchema: return .jsonSchema(schema.encoded(as: .jsonSchema))
        case .jsonObject: return .jsonObject
        }
    }

    // MARK: - Helpers

    private static func dataURL(mimeType: String, data: String) -> String {
        "data:\(mimeType);base64,\(data)"
    }

    private static func filename(for mimeType: String) -> String {
        switch mimeType {
        case "application/pdf": "document.pdf"
        case "text/plain": "document.txt"
        default: "attachment"
        }
    }
}
