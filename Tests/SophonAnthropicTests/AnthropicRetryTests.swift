//
//  AnthropicRetryTests.swift
//  SophonAnthropicTests
//
//  End-to-end through the mock transport: overload retry, the 413 path that
//  re-encodes images smaller, and paged model listing.
//

import Foundation
import SophonAnthropic
import SophonCore
import SophonTestSupport
import Testing

@MainActor @Suite(.serialized)
struct AnthropicRetryTests {
    private static let hello = #"{"content":[{"type":"text","text":"hello"}],"stop_reason":"end_turn"}"#
    private static let host = "api.anthropic.com"

    private func makeClient() -> AnthropicAPIClient {
        let configuration = AnthropicClientConfiguration(
            keychainAccount: "com.sophon.tests.anthropic.retry",
            defaults: LLMTestSupport.makeDefaults(),
            retryPolicy: LLMRetryPolicy(maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.002, usesJitter: false),
            logHandler: { _, _ in }
        )
        return AnthropicAPIClient(configuration: configuration, session: LLMMockURLProtocol.makeSession())
    }

    @Test
    func `529 overload is retried`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([
            .init(statusCode: 529, json: #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#),
            .init(statusCode: 200, json: Self.hello),
        ], for: Self.host)
        let client = makeClient()

        let result = try await client.sendPlainText(label: "test") { variant in
            try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
        }

        #expect(result == "hello")
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 2)
    }

    @Test
    func `413 retries with compressed images`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([.init(statusCode: 413, json: "{}"), .init(statusCode: 200, json: Self.hello)], for: Self.host)
        let client = makeClient()

        var compressed: [Bool] = []
        let result = try await client.sendPlainText(label: "test") { variant in
            compressed.append(variant.useCompressedImages)
            return try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
        }

        #expect(result == "hello")
        #expect(compressed == [false, true])
    }

    @Test
    func `Model listing follows pagination`() async throws {
        let client = makeClient()
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([
            .init(statusCode: 200, json: #"{"data":[{"id":"claude-opus-5","display_name":"Claude Opus 5","max_input_tokens":1000000,"max_tokens":128000}],"has_more":true,"last_id":"claude-opus-5"}"#),
            .init(statusCode: 200, json: #"{"data":[{"id":"claude-haiku-4-5","display_name":"Claude Haiku 4.5"}],"has_more":false,"last_id":"claude-haiku-4-5"}"#),
        ], for: Self.host)

        // The explicit-key overload keeps the test out of the Keychain, which the
        // simulator test host cannot write to.
        let models = try await client.listModels(apiKey: "test-key")

        #expect(models.map(\.id) == ["claude-opus-5", "claude-haiku-4-5"])
        #expect(models.first?.inputTokenLimit == 1_000_000)
        #expect(models.first?.outputTokenLimit == 128_000)
        let requests = LLMMockURLProtocol.requests(for: Self.host)
        #expect(requests.count == 2)
        #expect(requests.last?.url?.absoluteString.contains("after_id=claude-opus-5") == true)
        #expect(requests.first?.value(forHTTPHeaderField: "x-api-key") == "test-key")
    }
}
