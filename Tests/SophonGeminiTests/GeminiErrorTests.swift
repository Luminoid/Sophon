//
//  GeminiErrorTests.swift
//  SophonGeminiTests
//
//  Unit tests for GeminiError retry classification and string resolution
//  (Gemini-flavored keys from this target, shared copy from SophonCore).
//

import Foundation
import SophonGemini
import Testing

struct GeminiErrorTests {
    // MARK: - Retry Classification

    @Test
    func `isRetryable distinguishes transient from permanent errors`() {
        #expect(GeminiError.rateLimited.isRetryable)
        #expect(GeminiError.serverError(503).isRetryable)
        #expect(GeminiError.serverError(500).isRetryable)
        #expect(GeminiError.requestFailed(URLError(.timedOut)).isRetryable)
        #expect(GeminiError.requestTooLarge.isRetryable)

        #expect(!GeminiError.serverError(400).isRetryable)
        #expect(!GeminiError.invalidRequest("bad").isRetryable)
        #expect(!GeminiError.invalidAPIKey.isRetryable)
        #expect(!GeminiError.apiKeyInaccessible(-25308).isRetryable)
        #expect(!GeminiError.invalidResponse.isRetryable)
        #expect(!GeminiError.contentBlocked("SAFETY").isRetryable)
        #expect(!GeminiError.responseTruncated.isRetryable)
        #expect(!GeminiError.requestFailed(URLError(.cancelled)).isRetryable)
    }

    @Test
    func `isModelRetired matches only modelRetired`() {
        #expect(GeminiError.modelRetired("gemini-x").isModelRetired)
        #expect(!GeminiError.invalidResponse.isModelRetired)
    }

    @Test
    func `Image compression applies to transport failures and oversized requests`() {
        #expect(GeminiError.requestFailed(URLError(.timedOut)).shouldCompressImagesOnRetry)
        #expect(GeminiError.requestTooLarge.shouldCompressImagesOnRetry)
        #expect(GeminiError.requestTooLarge.retriesOnlyWithSmallerImages)
        #expect(!GeminiError.requestFailed(URLError(.timedOut)).retriesOnlyWithSmallerImages)
        #expect(!GeminiError.rateLimited.shouldCompressImagesOnRetry)
        #expect(!GeminiError.serverError(503).shouldCompressImagesOnRetry)
    }

    // MARK: - Localization

    @Test
    func `errorDescription resolves from the package strings`() throws {
        // A raw-key description means a missing bundle: .module or strings entry.
        let cases: [GeminiError] = [
            .apiKeyMissing, .apiKeyInaccessible(-25308), .invalidAPIKey, .invalidModelID("bad model"), .invalidRequest("bad"),
            .emptyInput, .imageEncodingFailed, .requestFailed(URLError(.timedOut)), .invalidResponse,
            .rateLimited, .requestTooLarge, .serverError(500), .modelRetired("gemini-x"),
            .contentBlocked("SAFETY"), .responseTruncated,
        ]
        for error in cases {
            let description = try #require(error.errorDescription)
            #expect(!description.isEmpty)
            #expect(!description.hasPrefix("gemini.error."))
            #expect(!description.hasPrefix("llm.error."))
        }
    }

    @Test
    func `parameterized descriptions carry their payload`() throws {
        let server = try #require(GeminiError.serverError(503).errorDescription)
        #expect(server.contains("503"))

        let retired = try #require(GeminiError.modelRetired("gemini-9-ultra").errorDescription)
        #expect(retired.contains("gemini-9-ultra"))

        let invalidID = try #require(GeminiError.invalidModelID("bad model").errorDescription)
        #expect(invalidID.contains("bad model"))

        let invalidRequest = try #require(GeminiError.invalidRequest("Invalid JSON payload").errorDescription)
        #expect(invalidRequest.contains("Invalid JSON payload"))
    }
}
