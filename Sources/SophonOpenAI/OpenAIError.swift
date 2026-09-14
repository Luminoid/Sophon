//
//  OpenAIError.swift
//  SophonOpenAI
//
//  Errors surfaced by the OpenAI-compatible request pipeline, with retry
//  classification. Key errors carry the endpoint's display name so a Groq or
//  DeepSeek user reads the right provider in the copy. User-facing copy
//  resolves from the package's string catalog.
//

import Foundation
import SophonCore

public enum OpenAIError: LLMClientError {
    case apiKeyMissing(provider: String)
    case invalidAPIKey(provider: String)
    /// The endpoint base URL and path could not form a request URL (carries the offending string).
    case invalidEndpoint(String)
    /// The provider rejected the request (HTTP 400); carries the provider's message.
    case invalidRequest(String)
    /// The caller had nothing to send (empty text input). Thrown by app services, not the client.
    case emptyInput
    case imageEncodingFailed
    case requestFailed(Error)
    case invalidResponse
    case rateLimited
    /// The account has no remaining credit or quota (HTTP 402, or 429 with a billing code). Not retryable.
    case insufficientQuota
    case serverError(Int)
    case modelRetired(String)
    /// The provider refused or filtered the content (carries the reason: "refusal", "content_filter").
    case contentBlocked(String)
    /// The provider hit the output-token limit, so the response is incomplete.
    case responseTruncated

    public var errorDescription: String? {
        switch self {
        case let .apiKeyMissing(provider):
            String(format: String(localized: "openai.error.apiKeyMissing", bundle: .module), provider)
        case let .invalidAPIKey(provider):
            String(format: String(localized: "openai.error.invalidAPIKey", bundle: .module), provider)
        case let .invalidEndpoint(url):
            String(localized: "openai.error.invalidEndpoint", bundle: .module) + " (\(url))"
        case let .invalidRequest(message):
            String(localized: "openai.error.invalidRequest", bundle: .module) + " (\(message))"
        case .emptyInput:
            String(localized: "openai.error.emptyInput", bundle: .module)
        case .imageEncodingFailed:
            String(localized: "openai.error.imageEncodingFailed", bundle: .module)
        case let .requestFailed(error):
            String(localized: "openai.error.networkError", bundle: .module) + " (\(error.localizedDescription))"
        case .invalidResponse:
            String(localized: "openai.error.invalidResponse", bundle: .module)
        case .rateLimited:
            String(localized: "openai.error.rateLimited", bundle: .module)
        case .insufficientQuota:
            String(localized: "openai.error.insufficientQuota", bundle: .module)
        case let .serverError(code):
            String(localized: "openai.error.serverError", bundle: .module) + " (\(code))"
        case let .modelRetired(name):
            String(localized: "openai.error.modelRetired", bundle: .module) + " (\(name))"
        case .contentBlocked:
            String(localized: "openai.error.contentBlocked", bundle: .module)
        case .responseTruncated:
            String(localized: "openai.error.responseTruncated", bundle: .module)
        }
    }

    // MARK: - Retry Classification

    public var isRetryable: Bool {
        switch self {
        case .rateLimited:
            true
        case let .serverError(code):
            LLMHTTP.isRetryableServerCode(code)
        case let .requestFailed(error):
            LLMHTTP.isRetryableURLError(error)
        default:
            false
        }
    }

    public var isModelRetired: Bool {
        if case .modelRetired = self { return true }
        return false
    }

    public var shouldCompressImagesOnRetry: Bool {
        if case .requestFailed = self { return true }
        return false
    }
}
