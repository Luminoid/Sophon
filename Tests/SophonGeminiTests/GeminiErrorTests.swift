//
//  GeminiErrorTests.swift
//  SophonGeminiTests
//
//  Unit tests for GeminiError retry classification and string-catalog resolution.
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

        #expect(!GeminiError.serverError(400).isRetryable)
        #expect(!GeminiError.invalidAPIKey.isRetryable)
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
    func `shouldCompressImagesOnRetry only for transport failures`() {
        #expect(GeminiError.requestFailed(URLError(.timedOut)).shouldCompressImagesOnRetry)
        #expect(!GeminiError.rateLimited.shouldCompressImagesOnRetry)
        #expect(!GeminiError.serverError(503).shouldCompressImagesOnRetry)
    }

    // MARK: - Localization

    @Test
    func `errorDescription resolves from the package string catalog`() throws {
        // A raw-key description means a missing bundle: .module or catalog entry.
        let cases: [GeminiError] = [
            .apiKeyMissing, .invalidAPIKey, .invalidModelID("bad model"), .emptyInput,
            .imageEncodingFailed, .requestFailed(URLError(.timedOut)), .invalidResponse,
            .rateLimited, .serverError(500), .modelRetired("gemini-x"),
            .contentBlocked("SAFETY"), .responseTruncated,
        ]
        for error in cases {
            let description = try #require(error.errorDescription)
            #expect(!description.isEmpty)
            #expect(!description.hasPrefix("gemini.error."))
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
    }
}
