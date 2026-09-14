//
//  OpenAIEndpointKnobsTests.swift
//  SophonOpenAITests
//
//  A custom `OpenAIEndpoint` exercising the knobs no preset sets: extra
//  headers, a non-Bearer auth header, `max_completion_tokens` on Chat
//  Completions; plus the message edge cases (empty messages skipped, a
//  schema that cannot be rendered fails the request).
//

import Foundation
import SophonCore
import SophonOpenAI
import SophonTestSupport
import Testing

@MainActor
struct OpenAIEndpointKnobsTests {
    private static let gateway = OpenAIEndpoint(
        displayName: "Gateway",
        keyPrefix: "gateway",
        baseURL: URL(string: "https://gateway.example.com/openai/v1") ?? URL(fileURLWithPath: "/"),
        wireFormat: .chatCompletions,
        structuredOutputMode: .jsonSchema,
        maxTokensField: .maxCompletionTokens,
        authorizationHeaderField: "api-key",
        authorizationValuePrefix: "",
        extraHeaders: ["X-Gateway-Version": "2"]
    )

    private func makeClient() -> OpenAIAPIClient {
        OpenAIAPIClient(configuration: OpenAIClientConfiguration(
            keychainAccount: "com.sophon.tests.gateway", endpoint: Self.gateway, defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }
        ))
    }

    @Test
    func `Custom auth header, extra headers, and max_completion_tokens reach the request`() throws {
        let request = try makeClient().buildRequest(promptText: "P", apiKey: "SECRET")
        #expect(request.url?.absoluteString == "https://gateway.example.com/openai/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "api-key") == "SECRET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-Gateway-Version") == "2")

        let json = try #require(LLMTestSupport.jsonObject(request.httpBody))
        #expect(json["max_completion_tokens"] as? Int == 16000)
        #expect(json["max_tokens"] == nil)
    }

    @Test
    func `Derived defaults keys and configuration keys follow the custom prefix`() {
        let configuration = makeClient().configuration
        #expect(configuration.enabledDefaultsKey == "ai.gatewayEnabled")
        #expect(configuration.modelDefaultsKey == "ai.gatewayModel")
        #expect(configuration.customModelDefaultsKey == "ai.gatewayCustomModel")
    }

    @Test
    func `Messages without parts are skipped on both wire formats`() throws {
        let contents: [LLMMessage] = [
            LLMMessage(parts: [.text("system")], role: .system),
            LLMMessage(parts: [], role: .user),
            LLMMessage(parts: [.text("hello")], role: .user),
        ]
        let chat = try makeClient().buildMultiTurnRequest(contents: contents, apiKey: "k")
        let chatMessages = try #require(LLMTestSupport.jsonObject(chat.httpBody)?["messages"] as? [[String: Any]])
        #expect(chatMessages.map { $0["role"] as? String } == ["system", "user"])

        let responses = OpenAIAPIClient(configuration: OpenAIClientConfiguration(keychainAccount: "com.sophon.tests.openAI", defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }))
        let request = try responses.buildMultiTurnRequest(contents: contents, apiKey: "k")
        let input = try #require(LLMTestSupport.jsonObject(request.httpBody)?["input"] as? [[String: Any]])
        #expect(input.count == 1)
    }
}
