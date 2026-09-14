//
//  GeminiAPIClientRetryTests.swift
//  SophonGeminiTests
//
//  Tests for the retry-aware send layer through the shared mock transport:
//  transient-error backoff, permanent-error short-circuit, 404 model fallback,
//  the 413 re-encode, safety/truncation surfacing, and the difference between
//  the .default and .minimal retry policies.
//

import Foundation
import SophonGemini
import SophonTestSupport
import Testing

@MainActor @Suite(.serialized)
struct GeminiAPIClientRetryTests {
    private static let host = "generativelanguage.googleapis.com"
    private static let validPlainTextBody = #"{"candidates":[{"content":{"parts":[{"text":"hello"}]},"finishReason":"STOP"}]}"#

    private func makeClient(
        policy: GeminiRetryPolicy = .default,
        defaults: UserDefaults? = nil
    ) -> GeminiAPIClient {
        let fast = GeminiRetryPolicy(
            maxAttempts: policy.maxAttempts,
            baseDelay: 0.001,
            maxDelay: 0.002,
            honorsRetryAfter: policy.honorsRetryAfter,
            usesJitter: policy.usesJitter,
            retriesWithFallbackModelOn404: policy.retriesWithFallbackModelOn404,
            downscalesImagesOnRetry: policy.downscalesImagesOnRetry
        )
        let configuration = TestSupport.makeConfiguration(defaults: defaults, retryPolicy: fast)
        return GeminiAPIClient(configuration: configuration, session: LLMMockURLProtocol.makeSession())
    }

    private static func simpleRequest() throws -> URLRequest {
        var request = try URLRequest(url: #require(URL(string: "https://generativelanguage.googleapis.com/test")))
        request.httpMethod = "POST"
        return request
    }

    private static func stub(_ statusCode: Int, json: String = "{}") -> LLMMockURLProtocol.Stub {
        .init(statusCode: statusCode, json: json)
    }

    // MARK: - Transient Retry

    @Test
    func `transient 503 is retried and succeeds on second attempt`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(503), Self.stub(200, json: Self.validPlainTextBody)], for: Self.host)
        let client = makeClient()

        let result = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }

        #expect(result == "hello")
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 2)
    }

    @Test
    func `minimal policy still retries transient errors`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(503), Self.stub(200, json: Self.validPlainTextBody)], for: Self.host)
        let client = makeClient(policy: .minimal)

        let result = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }

        #expect(result == "hello")
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 2)
    }

    @Test
    func `permanent 401 is not retried`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(401)], for: Self.host)
        let client = makeClient()

        var caught: GeminiError?
        do {
            _ = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }
        } catch let error as GeminiError {
            caught = error
        }

        guard let caught, case .invalidAPIKey = caught else {
            Issue.record("Expected invalidAPIKey, got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 1)
    }

    @Test
    func `413 retries once with compressed images, then fails`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(413), Self.stub(200, json: Self.validPlainTextBody)], for: Self.host)
        let client = makeClient()

        var compressed: [Bool] = []
        let result = try await client.sendPlainText(label: "test") { variant in
            compressed.append(variant.useCompressedImages)
            return try Self.simpleRequest()
        }
        #expect(result == "hello")
        #expect(compressed == [false, true])

        // A second 413 after the re-encode is final: no identical third upload.
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(413)], for: Self.host)
        var caught: GeminiError?
        do {
            _ = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }
        } catch let error as GeminiError {
            caught = error
        }
        guard let caught, case .requestTooLarge = caught else {
            Issue.record("Expected requestTooLarge, got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 2)
    }

    // MARK: - Model Fallback

    @Test
    func `404 retries against the fallback model and persists the reset`() async throws {
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("gemini35Flash", forKey: "ai.geminiModel") // != fallback

        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(404), Self.stub(200, json: Self.validPlainTextBody)], for: Self.host)
        let client = makeClient(defaults: defaults)

        var seenModels: [String] = []
        let result = try await client.sendPlainText(label: "test") { variant in
            seenModels.append(variant.modelID)
            return try Self.simpleRequest()
        }

        #expect(result == "hello")
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 2)
        #expect(seenModels.first == "gemini-3.5-flash")
        #expect(seenModels.last == GeminiModel.gemini31FlashLite.modelID)
        #expect(defaults.string(forKey: "ai.geminiModel") == GeminiModel.gemini31FlashLite.storageKey)
    }

    @Test
    func `minimal policy fails the call on 404 but still persists the reset`() async throws {
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("gemini35Flash", forKey: "ai.geminiModel")

        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(404)], for: Self.host)
        let client = makeClient(policy: .minimal, defaults: defaults)

        var caught: GeminiError?
        do {
            _ = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }
        } catch let error as GeminiError {
            caught = error
        }

        guard let caught, case .modelRetired = caught else {
            Issue.record("Expected modelRetired, got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 1)
        #expect(defaults.string(forKey: "ai.geminiModel") == GeminiModel.gemini31FlashLite.storageKey)
    }

    // MARK: - Safety / Truncation Surfacing

    @Test
    func `prompt block reason surfaces as contentBlocked`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        LLMMockURLProtocol.setStubs([Self.stub(200, json: #"{"promptFeedback":{"blockReason":"SAFETY"}}"#)], for: Self.host)
        let client = makeClient()

        var caught: GeminiError?
        do {
            _ = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }
        } catch let error as GeminiError {
            caught = error
        }

        guard let caught, case .contentBlocked = caught else {
            Issue.record("Expected contentBlocked, got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 1) // not retried
    }

    @Test
    func `MAX_TOKENS finish reason surfaces as responseTruncated`() async throws {
        LLMMockURLProtocol.reset(host: Self.host)
        let body = #"{"candidates":[{"content":{"parts":[{"text":"partial"}]},"finishReason":"MAX_TOKENS"}]}"#
        LLMMockURLProtocol.setStubs([Self.stub(200, json: body)], for: Self.host)
        let client = makeClient()

        var caught: GeminiError?
        do {
            _ = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }
        } catch let error as GeminiError {
            caught = error
        }

        guard let caught, case .responseTruncated = caught else {
            Issue.record("Expected responseTruncated, got \(String(describing: caught))")
            return
        }
        #expect(LLMMockURLProtocol.requestCount(for: Self.host) == 1)
    }

    // MARK: - Pure Policy Helpers

    @Test
    func `default policy backoff grows exponentially and stays capped`() {
        let policy = GeminiRetryPolicy.default
        let d1 = policy.backoffDelay(retry: 1, retryAfter: nil)
        let d2 = policy.backoffDelay(retry: 2, retryAfter: nil)
        #expect(d1 >= policy.baseDelay)
        #expect(d2 > d1)
        #expect(policy.backoffDelay(retry: 10, retryAfter: nil) <= policy.maxDelay)
        #expect(policy.backoffDelay(retry: 1, retryAfter: 2.0) == 2.0)
    }

    @Test
    func `minimal policy ignores RetryAfter and jitter`() {
        let policy = GeminiRetryPolicy.minimal
        #expect(policy.backoffDelay(retry: 1, retryAfter: 5.0) == 1.0)
        #expect(policy.backoffDelay(retry: 2, retryAfter: nil) == 2.0)
    }
}
