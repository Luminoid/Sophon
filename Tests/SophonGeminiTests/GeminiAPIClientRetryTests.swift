//
//  GeminiAPIClientRetryTests.swift
//  SophonGeminiTests
//
//  Tests for the retry-aware send layer: transient-error backoff, permanent-error
//  short-circuit, 404 model fallback, safety/truncation surfacing, and the
//  difference between the .default and .minimal retry policies.
//

import Foundation
import SophonGemini
import Testing

// MARK: - Mock URL Protocol

/// Returns a fixed sequence of canned responses, one per request, so the retry loop can be driven
/// deterministically. The last stub repeats if more requests arrive than stubs were provided.
final class GeminiMockURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let body: Data
        let headers: [String: String]
    }

    nonisolated(unsafe) static var stubs: [Stub] = []
    nonisolated(unsafe) static var requestCount = 0

    static func reset() {
        stubs = []
        requestCount = 0
    }

    // URLProtocol requirements are `class func`s, so `static` cannot override them.
    // swiftlint:disable static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    // swiftlint:enable static_over_final_class

    override func startLoading() {
        guard !Self.stubs.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let index = min(Self.requestCount, Self.stubs.count - 1)
        Self.requestCount += 1
        let stub = Self.stubs[index]
        guard let url = request.url ?? URL(string: "https://example.com"),
              let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: nil, headerFields: stub.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@MainActor @Suite(.serialized)
struct GeminiAPIClientRetryTests {
    private static let validPlainTextBody = Data(#"{"candidates":[{"content":{"parts":[{"text":"hello"}]},"finishReason":"STOP"}]}"#.utf8)

    private func makeClient(
        policy: GeminiRetryPolicy = .default,
        defaults: UserDefaults? = nil
    ) -> GeminiAPIClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [GeminiMockURLProtocol.self]
        let configuration = TestSupport.makeConfiguration(defaults: defaults, retryPolicy: policy)
        return GeminiAPIClient(configuration: configuration, session: URLSession(configuration: sessionConfig))
    }

    private static func simpleRequest() throws -> URLRequest {
        var request = try URLRequest(url: #require(URL(string: "https://generativelanguage.googleapis.com/test")))
        request.httpMethod = "POST"
        return request
    }

    // MARK: - Transient Retry

    @Test
    func `transient 503 is retried and succeeds on second attempt`() async throws {
        GeminiMockURLProtocol.reset()
        GeminiMockURLProtocol.stubs = [
            .init(statusCode: 503, body: Data("{}".utf8), headers: [:]),
            .init(statusCode: 200, body: Self.validPlainTextBody, headers: [:]),
        ]
        let client = makeClient()

        let result = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }

        #expect(result == "hello")
        #expect(GeminiMockURLProtocol.requestCount == 2)
    }

    @Test
    func `minimal policy still retries transient errors`() async throws {
        GeminiMockURLProtocol.reset()
        GeminiMockURLProtocol.stubs = [
            .init(statusCode: 503, body: Data("{}".utf8), headers: [:]),
            .init(statusCode: 200, body: Self.validPlainTextBody, headers: [:]),
        ]
        let client = makeClient(policy: .minimal)

        let result = try await client.sendPlainText(label: "test") { _ in try Self.simpleRequest() }

        #expect(result == "hello")
        #expect(GeminiMockURLProtocol.requestCount == 2)
    }

    @Test
    func `permanent 401 is not retried`() async throws {
        GeminiMockURLProtocol.reset()
        GeminiMockURLProtocol.stubs = [.init(statusCode: 401, body: Data("{}".utf8), headers: [:])]
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
        #expect(GeminiMockURLProtocol.requestCount == 1)
    }

    // MARK: - Model Fallback

    @Test
    func `404 retries against the fallback model and persists the reset`() async throws {
        let defaults = TestSupport.makeDefaults()
        defaults.set("gemini35Flash", forKey: "ai.geminiModel") // != fallback

        GeminiMockURLProtocol.reset()
        GeminiMockURLProtocol.stubs = [
            .init(statusCode: 404, body: Data("{}".utf8), headers: [:]),
            .init(statusCode: 200, body: Self.validPlainTextBody, headers: [:]),
        ]
        let client = makeClient(defaults: defaults)

        var seenModels: [String] = []
        let result = try await client.sendPlainText(label: "test") { variant in
            seenModels.append(variant.modelID)
            return try Self.simpleRequest()
        }

        #expect(result == "hello")
        #expect(GeminiMockURLProtocol.requestCount == 2)
        #expect(seenModels.first == "gemini-3.5-flash")
        #expect(seenModels.last == GeminiModel.gemini31FlashLite.modelID)
        #expect(defaults.string(forKey: "ai.geminiModel") == GeminiModel.gemini31FlashLite.storageKey)
    }

    @Test
    func `minimal policy fails the call on 404 but still persists the reset`() async throws {
        let defaults = TestSupport.makeDefaults()
        defaults.set("gemini35Flash", forKey: "ai.geminiModel")

        GeminiMockURLProtocol.reset()
        GeminiMockURLProtocol.stubs = [.init(statusCode: 404, body: Data("{}".utf8), headers: [:])]
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
        #expect(GeminiMockURLProtocol.requestCount == 1)
        #expect(defaults.string(forKey: "ai.geminiModel") == GeminiModel.gemini31FlashLite.storageKey)
    }

    // MARK: - Safety / Truncation Surfacing

    @Test
    func `prompt block reason surfaces as contentBlocked`() async throws {
        GeminiMockURLProtocol.reset()
        let body = Data(#"{"promptFeedback":{"blockReason":"SAFETY"}}"#.utf8)
        GeminiMockURLProtocol.stubs = [.init(statusCode: 200, body: body, headers: [:])]
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
        #expect(GeminiMockURLProtocol.requestCount == 1) // not retried
    }

    @Test
    func `MAX_TOKENS finish reason surfaces as responseTruncated`() async throws {
        GeminiMockURLProtocol.reset()
        let body = Data(#"{"candidates":[{"content":{"parts":[{"text":"partial"}]},"finishReason":"MAX_TOKENS"}]}"#.utf8)
        GeminiMockURLProtocol.stubs = [.init(statusCode: 200, body: body, headers: [:])]
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
        #expect(GeminiMockURLProtocol.requestCount == 1)
    }

    // MARK: - Pure Policy Helpers

    @Test
    func `retryAfter header is parsed and clamped`() {
        let three = TestSupport.makeHTTPResponse(status: 429, headers: ["Retry-After": "3"])
        #expect(GeminiAPIClient.retryAfterSeconds(from: three, cap: 6.0) == 3)

        let huge = TestSupport.makeHTTPResponse(status: 429, headers: ["Retry-After": "9999"])
        #expect(GeminiAPIClient.retryAfterSeconds(from: huge, cap: 6.0) == 6.0)

        let absent = TestSupport.makeHTTPResponse(status: 429, headers: nil)
        #expect(GeminiAPIClient.retryAfterSeconds(from: absent, cap: 6.0) == nil)
    }

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
