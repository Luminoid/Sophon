//
//  LLMRetryLoopTests.swift
//  SophonCoreTests
//
//  Unit tests for the shared retry loop with a fake error type: transient
//  backoff, permanent short-circuit, one-shot fallback on a retired model,
//  image downscale on transport failure, and unclassified errors passing
//  through unretried.
//

import Foundation
import SophonCore
import Testing

private enum FakeError: LLMClientError {
    case transient
    case permanent
    case retired
    case transport

    var isRetryable: Bool { self == .transient || self == .transport }
    var isModelRetired: Bool { self == .retired }
    var shouldCompressImagesOnRetry: Bool { self == .transport }
    var errorDescription: String? { nil }
}

private struct UnrelatedError: Error {}

struct LLMRetryLoopTests {
    /// Sub-millisecond delays so the backoff path runs without slowing the suite.
    private static let fastPolicy = LLMRetryPolicy(maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.002, honorsRetryAfter: true, usesJitter: false)

    private static func makeResponse(headers: [String: String]? = nil) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://example.com"))
        return try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers))
    }

    /// Runs the loop with `outcomes` consumed one per attempt: nil means decode
    /// succeeds, an error means decode throws it.
    private static func run(
        policy: LLMRetryPolicy = fastPolicy,
        outcomes: [Error?],
        headers: [String: String]? = nil
    ) async throws -> (result: String, variants: [LLMRequestVariant]) {
        var remaining = outcomes
        var variants: [LLMRequestVariant] = []
        let response = try makeResponse(headers: headers)
        let result = try await LLMRetryLoop.run(
            providerName: "Fake",
            label: "test",
            policy: policy,
            initialModelID: "primary",
            fallbackModelID: "fallback",
            log: { _, _ in },
            buildRequest: { variant in
                variants.append(variant)
                return URLRequest(url: response.url ?? URL(fileURLWithPath: "/"))
            },
            perform: { _ in (Data(), response) },
            decode: { _, _ in
                let outcome = remaining.isEmpty ? nil : remaining.removeFirst()
                if let outcome { throw outcome }
                return "ok"
            }
        )
        return (result, variants)
    }

    @Test
    func `Transient errors are retried up to the policy's attempts`() async throws {
        let (result, variants) = try await Self.run(outcomes: [FakeError.transient, FakeError.transient, nil])
        #expect(result == "ok")
        #expect(variants.count == 3)
        #expect(variants.allSatisfy { $0.modelID == "primary" })
    }

    @Test
    func `Exhausting the attempts rethrows the transient error`() async {
        await #expect(throws: FakeError.self) {
            _ = try await Self.run(outcomes: [FakeError.transient, FakeError.transient, FakeError.transient, nil])
        }
    }

    @Test
    func `Permanent errors are not retried`() async throws {
        var attempts = 0
        do {
            _ = try await Self.run(outcomes: [FakeError.permanent, nil])
        } catch FakeError.permanent {
            attempts = 1
        }
        #expect(attempts == 1)
    }

    @Test
    func `A retired model retries once on the fallback model`() async throws {
        let (result, variants) = try await Self.run(outcomes: [FakeError.retired, nil])
        #expect(result == "ok")
        #expect(variants.map(\.modelID) == ["primary", "fallback"])
    }

    @Test
    func `A retired fallback is not retried again`() async {
        await #expect(throws: FakeError.self) {
            _ = try await Self.run(outcomes: [FakeError.retired, FakeError.retired, nil])
        }
    }

    @Test
    func `Fallback retry is policy-gated`() async {
        let policy = LLMRetryPolicy(maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.002, retriesWithFallbackModelOn404: false)
        await #expect(throws: FakeError.self) {
            _ = try await Self.run(policy: policy, outcomes: [FakeError.retired, nil])
        }
    }

    @Test
    func `Transport failures request compressed images on the retry`() async throws {
        let (_, variants) = try await Self.run(outcomes: [FakeError.transport, nil])
        #expect(variants.map(\.useCompressedImages) == [false, true])

        let policy = LLMRetryPolicy(maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.002, downscalesImagesOnRetry: false)
        let (_, plain) = try await Self.run(policy: policy, outcomes: [FakeError.transport, nil])
        #expect(plain.map(\.useCompressedImages) == [false, false])
    }

    @Test
    func `Errors outside LLMClientError propagate without retry`() async {
        await #expect(throws: UnrelatedError.self) {
            _ = try await Self.run(outcomes: [UnrelatedError(), nil])
        }
    }

    @Test
    func `A Retry-After header is honored and clamped to maxDelay`() async throws {
        // Retry-After of 9999s must not stall the test: the policy caps it at 2 ms.
        let (result, variants) = try await Self.run(outcomes: [FakeError.transient, nil], headers: ["Retry-After": "9999"])
        #expect(result == "ok")
        #expect(variants.count == 2)
    }
}
