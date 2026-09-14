//
//  AnthropicWireEdgeTests.swift
//  SophonAnthropicTests
//
//  Wire edge cases: plain-text documents as text sources, empty messages
//  skipped, base-URL normalization, and the catalog's key hint.
//

import Foundation
import SophonAnthropic
import SophonCore
import SophonTestSupport
import Testing

@MainActor
struct AnthropicWireEdgeTests {
    private func makeClient(apiBaseURL: String = "https://api.anthropic.com/v1/") -> AnthropicAPIClient {
        AnthropicAPIClient(configuration: AnthropicClientConfiguration(
            keychainAccount: "com.sophon.tests.anthropic.edge", defaults: LLMTestSupport.makeDefaults(), apiBaseURL: apiBaseURL, logHandler: { _, _ in }
        ))
    }

    @Test
    func `A plain-text document is sent decoded as a text source`() throws {
        let encoded = Data("Hello, document".utf8).base64EncodedString()
        let request = try makeClient().buildRequest(parts: [.inlineData(mimeType: "text/plain", data: encoded)], promptText: "Summarize", apiKey: "k")
        let messages = try #require(LLMTestSupport.jsonObject(request.httpBody)?["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? [[String: Any]])
        let document = try #require(content.first)
        #expect(document["type"] as? String == "document")
        let source = try #require(document["source"] as? [String: Any])
        #expect(source["type"] as? String == "text")
        #expect(source["media_type"] as? String == "text/plain")
        #expect(source["data"] as? String == "Hello, document")
    }

    @Test
    func `Messages without parts are skipped`() throws {
        let contents: [LLMMessage] = [
            LLMMessage(parts: [], role: .user),
            LLMMessage(parts: [.text("hello")], role: .user),
        ]
        let request = try makeClient().buildMultiTurnRequest(contents: contents, apiKey: "k")
        let messages = try #require(LLMTestSupport.jsonObject(request.httpBody)?["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
    }

    @Test
    func `A base URL without a trailing slash still builds the messages URL`() throws {
        let request = try makeClient(apiBaseURL: "https://proxy.example.com/anthropic/v1").buildRequest(promptText: "P", apiKey: "k")
        #expect(request.url?.absoluteString == "https://proxy.example.com/anthropic/v1/messages")

        var configuration = AnthropicClientConfiguration(keychainAccount: "com.sophon.tests.anthropic.edge", defaults: LLMTestSupport.makeDefaults())
        configuration.apiBaseURL = "https://proxy.example.com/v1//"
        #expect(configuration.apiBaseURL == "https://proxy.example.com/v1/")
    }

    @Test
    func `The catalog points at the Claude Console for a key`() {
        #expect(AnthropicModel.keyHintURL?.absoluteString == "https://platform.claude.com/settings/keys")
    }
}
