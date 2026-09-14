//
//  AnthropicRequestTests.swift
//  SophonAnthropicTests
//
//  Request building for the Messages API: headers (key never in the URL),
//  content blocks by MIME type with media before text, system hoisting,
//  structured output via output_config, effort, and temperature gating.
//

import Foundation
import SophonAnthropic
import SophonCore
import SophonTestSupport
import Testing

@MainActor
struct AnthropicRequestTests {
    private let schema = LLMSchema.object(properties: ["name": .string(), "score": .number()], required: ["name"])

    private func makeClient(effort: AnthropicEffort? = nil) -> AnthropicAPIClient {
        AnthropicAPIClient(configuration: AnthropicClientConfiguration(
            keychainAccount: "com.sophon.tests.anthropic", defaults: LLMTestSupport.makeDefaults(), effort: effort, logHandler: { _, _ in }
        ))
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try #require(LLMTestSupport.jsonObject(request.httpBody))
    }

    @Test
    func `Headers carry the key and version and the URL stays clean`() throws {
        let request = try makeClient().buildRequest(promptText: "P", apiKey: "SECRET")
        let url = try #require(request.url)
        #expect(url.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(!url.absoluteString.contains("SECRET"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "SECRET")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test
    func `Body carries model, max_tokens, typed blocks with media first, and strict output_config`() throws {
        let request = try makeClient().buildRequest(
            parts: [.inlineData(mimeType: "image/jpeg", data: "QUJD"), .inlineData(mimeType: "application/pdf", data: "REVG")],
            promptText: "Read both",
            apiKey: "k",
            responseSchema: schema
        )
        let json = try body(request)

        #expect(json["model"] as? String == "claude-sonnet-5")
        #expect(json["max_tokens"] as? Int == 16000)
        #expect(json["temperature"] == nil, "Sonnet 5 rejects sampling parameters")
        #expect(json["system"] == nil)
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] as? String == "user")
        let blocks = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(blocks.map { $0["type"] as? String } == ["image", "document", "text"])
        let image = try #require(blocks[0]["source"] as? [String: Any])
        #expect(image["type"] as? String == "base64")
        #expect(image["media_type"] as? String == "image/jpeg")
        #expect(image["data"] as? String == "QUJD")
        #expect((blocks[1]["source"] as? [String: Any])?["media_type"] as? String == "application/pdf")
        #expect(blocks[2]["text"] as? String == "Read both")

        let format = try #require((json["output_config"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let encoded = try #require(format["schema"] as? [String: Any])
        #expect(encoded["type"] as? String == "object")
        #expect(encoded["additionalProperties"] as? Bool == false)
        #expect(encoded["required"] as? [String] == ["name", "score"])
    }

    @Test
    func `Plain requests omit output_config unless effort is configured`() throws {
        let plain = try body(makeClient().buildMultiTurnRequest(contents: [LLMMessage(parts: [.text("hi")], role: .user)], apiKey: "k"))
        #expect(plain["output_config"] == nil)

        let withEffort = try body(makeClient(effort: .low).buildMultiTurnRequest(contents: [LLMMessage(parts: [.text("hi")], role: .user)], apiKey: "k"))
        let config = try #require(withEffort["output_config"] as? [String: Any])
        #expect(config["effort"] as? String == "low")
        #expect(config["format"] == nil)
    }

    @Test
    func `System messages are hoisted and provider role names map`() throws {
        let contents = [
            LLMMessage(parts: [.text("be terse")], role: .system),
            LLMMessage(parts: [.text("hello")], role: "user"),
            LLMMessage(parts: [.text("hi")], role: "model"),
            LLMMessage(parts: [.text("and now?")], role: .user),
        ]
        let json = try body(makeClient().buildMultiTurnRequest(contents: contents, apiKey: "k"))

        #expect(json["system"] as? String == "be terse")
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["user", "assistant", "user"])
        #expect(json["temperature"] == nil)
    }

    @Test
    func `Temperature is sent only for models that accept it`() throws {
        let client = makeClient()
        let haiku = try body(client.buildRequest(promptText: "P", apiKey: "k", modelID: "claude-haiku-4-5", temperature: 0.4))
        #expect(haiku["temperature"] as? Double == 0.4)

        let opus = try body(client.buildRequest(promptText: "P", apiKey: "k", modelID: "claude-opus-5", temperature: 0.4))
        #expect(opus["temperature"] == nil)

        let custom = try body(client.buildRequest(promptText: "P", apiKey: "k", modelID: "claude-future-9", temperature: 0.4))
        #expect(custom["temperature"] == nil)
        #expect(custom["model"] as? String == "claude-future-9")
    }
}
