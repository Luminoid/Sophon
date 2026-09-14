//
//  LLMHTTPTests.swift
//  SophonCoreTests
//
//  Retry-After parsing in both header forms, retry-policy input sanitizing,
//  the shared error copy resolving from SophonCore's own bundle, and catalog
//  date construction.
//

import Foundation
import SophonCore
import Testing

struct LLMHTTPTests {
    private static func response(retryAfter: String?) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://example.com"))
        let headers = retryAfter.map { ["Retry-After": $0] }
        return try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: headers))
    }

    @Test
    func `Retry-After in seconds is parsed and clamped`() throws {
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: "3"), cap: 6) == 3)
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: "9999"), cap: 6) == 6)
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: "-1"), cap: 6) == nil)
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: nil), cap: 6) == nil)
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: "soon"), cap: 6) == nil)
    }

    @Test
    func `Retry-After as an HTTP date becomes a delay from now`() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"

        let future = formatter.string(from: Date().addingTimeInterval(30))
        let delay = try #require(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: future), cap: 60))
        #expect(delay > 25 && delay <= 30)
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: future), cap: 6) == 6)

        let past = formatter.string(from: Date().addingTimeInterval(-30))
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: past), cap: 6) == 0)
        #expect(try LLMHTTP.retryAfterSeconds(from: Self.response(retryAfter: "Wed, 21 Oct 2015 07:28:00 GMT"), cap: 6) == 0)
    }

    @Test
    func `A retry policy sanitizes impossible delays and attempts`() {
        let broken = LLMRetryPolicy(maxAttempts: 0, baseDelay: -1, maxDelay: .nan)
        #expect(broken.maxAttempts == 1)
        #expect(broken.maxRetries == 0)
        #expect(broken.baseDelay == 0)
        #expect(broken.maxDelay == 6.0)
        #expect(broken.backoffDelay(retry: 1, retryAfter: -5) == 0)

        let infinite = LLMRetryPolicy(baseDelay: .infinity, maxDelay: .infinity)
        #expect(infinite.baseDelay == 0.8)
        #expect(infinite.maxDelay == 6.0)
    }

    @Test
    func `Shared error copy resolves from SophonCore's bundle`() {
        let cases: [LLMErrorCopy] = [
            .invalidResponse, .rateLimited, .networkError, .imageEncodingFailed,
            .emptyInput, .responseTruncated, .requestTooLarge, .apiKeyInaccessible,
        ]
        for copy in cases {
            #expect(!copy.text.isEmpty)
            #expect(!copy.text.hasPrefix("llm.error."), "\(copy) resolved to its raw key")
        }
    }

    @Test
    func `Catalog days are midnight UTC`() {
        let date = LLMModelInfo.day(2026, 9, 13)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        #expect(components.year == 2026 && components.month == 9 && components.day == 13 && components.hour == 0)
    }
}
