//
//  OpenAIErrorTests.swift
//  SophonOpenAITests
//
//  Retry classification and string resolution (including the provider-name
//  interpolation and the shared copy from SophonCore) for `OpenAIError`.
//

import Foundation
import SophonOpenAI
import Testing

struct OpenAIErrorTests {
    @Test
    func `isRetryable distinguishes transient from permanent errors`() {
        #expect(OpenAIError.rateLimited.isRetryable)
        #expect(OpenAIError.serverError(503).isRetryable)
        #expect(OpenAIError.requestFailed(URLError(.timedOut)).isRetryable)
        #expect(OpenAIError.requestTooLarge.isRetryable)

        #expect(!OpenAIError.insufficientQuota.isRetryable)
        #expect(!OpenAIError.invalidRequest("bad").isRetryable)
        #expect(!OpenAIError.invalidAPIKey(provider: "OpenAI").isRetryable)
        #expect(!OpenAIError.apiKeyInaccessible(-25308).isRetryable)
        #expect(!OpenAIError.contentBlocked("refusal").isRetryable)
        #expect(!OpenAIError.serverError(400).isRetryable)
    }

    @Test
    func `Model-retired and image-compression flags`() {
        #expect(OpenAIError.modelRetired("x").isModelRetired)
        #expect(!OpenAIError.rateLimited.isModelRetired)
        #expect(OpenAIError.requestFailed(URLError(.timedOut)).shouldCompressImagesOnRetry)
        #expect(OpenAIError.requestTooLarge.shouldCompressImagesOnRetry)
        #expect(OpenAIError.requestTooLarge.retriesOnlyWithSmallerImages)
        #expect(!OpenAIError.requestFailed(URLError(.timedOut)).retriesOnlyWithSmallerImages)
        #expect(!OpenAIError.rateLimited.shouldCompressImagesOnRetry)
    }

    @Test
    func `errorDescription resolves from the package strings`() throws {
        let cases: [OpenAIError] = [
            .apiKeyMissing(provider: "Groq"), .apiKeyInaccessible(-25308), .invalidAPIKey(provider: "Groq"), .invalidEndpoint("x"), .invalidRequest("y"),
            .emptyInput, .imageEncodingFailed, .requestFailed(URLError(.timedOut)), .invalidResponse, .rateLimited,
            .insufficientQuota, .requestTooLarge, .serverError(500), .modelRetired("m"), .contentBlocked("refusal"), .responseTruncated,
        ]
        for error in cases {
            let description = try #require(error.errorDescription)
            #expect(!description.isEmpty)
            #expect(!description.hasPrefix("openai.error."))
            #expect(!description.hasPrefix("llm.error."))
            #expect(!description.contains("%@"))
        }
        #expect(try #require(OpenAIError.apiKeyMissing(provider: "Groq").errorDescription).contains("Groq"))
        #expect(try #require(OpenAIError.modelRetired("gpt-9").errorDescription).contains("gpt-9"))
    }
}
