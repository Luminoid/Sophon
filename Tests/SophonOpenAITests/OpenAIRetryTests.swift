//
//  OpenAIRetryTests.swift
//  SophonOpenAITests
//
//  End-to-end through the mock transport: transient retry, the retired-model
//  fallback with persisted reset, the plain-404 no-reset path, and model
//  listing (including OpenRouter's free filter).
//

import Foundation
import SophonCore
import SophonOpenAI
import SophonTestSupport
import Testing

@MainActor @Suite(.serialized)
struct OpenAIRetryTests {
    private static let hello = #"{"choices":[{"message":{"role":"assistant","content":"hello"},"finish_reason":"stop"}]}"#
    private static let groqHost = "api.groq.com"
    private static let routerHost = "openrouter.ai"

    private func makeGroq(defaults: UserDefaults? = nil) -> GroqAPIClient {
        let configuration = GroqClientConfiguration(
            keychainAccount: "com.sophon.tests.groq",
            defaults: defaults ?? LLMTestSupport.makeDefaults(),
            retryPolicy: LLMRetryPolicy(maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.002, usesJitter: false),
            logHandler: { _, _ in }
        )
        return GroqAPIClient(configuration: configuration, session: LLMMockURLProtocol.makeSession())
    }

    @Test
    func `Transient 503 is retried and succeeds`() async throws {
        LLMMockURLProtocol.reset(host: Self.groqHost)
        LLMMockURLProtocol.setStubs([.init(statusCode: 503, json: "{}"), .init(statusCode: 200, json: Self.hello)], for: Self.groqHost)
        let client = makeGroq()

        let result = try await client.sendPlainText(label: "test") { variant in
            try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
        }

        #expect(result == "hello")
        #expect(LLMMockURLProtocol.requestCount(for: Self.groqHost) == 2)
    }

    @Test
    func `Unknown model retries on the fallback and persists the reset`() async throws {
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("llama3370BVersatile", forKey: "ai.groqModel")
        LLMMockURLProtocol.reset(host: Self.groqHost)
        LLMMockURLProtocol.setStubs([
            .init(statusCode: 404, json: #"{"error":{"message":"The model does not exist","code":"model_not_found"}}"#),
            .init(statusCode: 200, json: Self.hello),
        ], for: Self.groqHost)
        let client = makeGroq(defaults: defaults)

        var seen: [String] = []
        let result = try await client.sendPlainText(label: "test") { variant in
            seen.append(variant.modelID)
            return try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
        }

        #expect(result == "hello")
        #expect(seen == ["llama-3.3-70b-versatile", GroqModel.recommendedFallback.modelID])
        #expect(defaults.string(forKey: "ai.groqModel") == GroqModel.recommendedFallback.storageKey)
    }

    @Test
    func `A plain 404 fails without touching the selection`() async throws {
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("llama3370BVersatile", forKey: "ai.groqModel")
        LLMMockURLProtocol.reset(host: Self.groqHost)
        LLMMockURLProtocol.setStubs([.init(statusCode: 404, json: "{}")], for: Self.groqHost)
        let client = makeGroq(defaults: defaults)

        var caught: OpenAIError?
        do {
            _ = try await client.sendPlainText(label: "test") { variant in
                try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
            }
        } catch let error as OpenAIError {
            caught = error
        }

        guard case .serverError(404)? = caught else {
            Issue.record("Expected serverError(404), got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.groqHost) == 1)
        #expect(defaults.string(forKey: "ai.groqModel") == "llama3370BVersatile")
    }

    @Test
    func `413 retries once with compressed images and never re-sends an identical body`() async throws {
        LLMMockURLProtocol.reset(host: Self.groqHost)
        LLMMockURLProtocol.setStubs([.init(statusCode: 413, json: "{}"), .init(statusCode: 200, json: Self.hello)], for: Self.groqHost)
        let client = makeGroq()

        var compressed: [Bool] = []
        let result = try await client.sendPlainText(label: "test") { variant in
            compressed.append(variant.useCompressedImages)
            return try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
        }
        #expect(result == "hello")
        #expect(compressed == [false, true])

        LLMMockURLProtocol.reset(host: Self.groqHost)
        LLMMockURLProtocol.setStubs([.init(statusCode: 413, json: "{}")], for: Self.groqHost)
        var caught: OpenAIError?
        do {
            _ = try await client.sendPlainText(label: "test") { variant in
                try client.buildRequest(promptText: "hi", apiKey: "k", modelID: variant.modelID)
            }
        } catch let error as OpenAIError {
            caught = error
        }
        guard case .requestTooLarge? = caught else {
            Issue.record("Expected requestTooLarge, got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.groqHost) == 2)
    }

    @Test
    func `Model listing decodes ids and OpenRouter filters free ones`() async throws {
        // Listing needs a stored key, so a configuration without one throws before any request.
        let missingKey = makeGroq()
        await #expect(throws: OpenAIError.self) {
            _ = try await missingKey.listModels()
        }

        let router = OpenRouterAPIClient(
            configuration: OpenRouterClientConfiguration(keychainAccount: "com.sophon.tests.openRouter", defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }),
            session: LLMMockURLProtocol.makeSession()
        )
        LLMMockURLProtocol.reset(host: Self.routerHost)
        let listing = #"{"data":[{"id":"openrouter/auto","name":"Auto"},{"id":"nvidia/nemotron-3.5-lightning:free","name":"Nemotron","context_length":1000000}]}"#
        LLMMockURLProtocol.setStubs([.init(statusCode: 200, json: listing)], for: Self.routerHost)

        // The explicit-key overload keeps the test out of the Keychain, which the
        // simulator test host cannot write to.
        let all = try await router.listModels(apiKey: "test-key")
        #expect(all.map(\.id) == ["openrouter/auto", "nvidia/nemotron-3.5-lightning:free"])
        #expect(all.last?.inputTokenLimit == 1_000_000)
        let first = LLMMockURLProtocol.requests(for: Self.routerHost).first
        #expect(first?.url?.absoluteString == "https://openrouter.ai/api/v1/models")
        #expect(first?.httpMethod == "GET")
        #expect(first?.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")

        let free = try await router.listFreeModels(apiKey: "test-key")
        #expect(free.map(\.id) == ["nvidia/nemotron-3.5-lightning:free"])
    }
}
