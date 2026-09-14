//
//  OpenAIError.swift
//  SophonOpenAI
//
//  Errors surfaced by the OpenAI-compatible request pipeline, with retry
//  classification. Key errors carry the endpoint's display name so a Groq or
//  DeepSeek user reads the right provider in the copy. Provider-flavored copy
//  resolves from this target's strings; the cases every provider shares read
//  from `LLMErrorCopy` in SophonCore.
//

import Foundation
import SophonCore

public enum OpenAIError: LLMClientError {
    case apiKeyMissing(provider: String)
    /// The Keychain refused to hand over the stored key (device locked); carries the OSStatus.
    case apiKeyInaccessible(OSStatus)
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
    /// HTTP 413: the request body is too large. Retried with smaller images
    /// when the request builder can re-encode them; fails at once otherwise.
    case requestTooLarge
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
        case .apiKeyInaccessible:
            LLMErrorCopy.apiKeyInaccessible.text
        case let .invalidAPIKey(provider):
            String(format: String(localized: "openai.error.invalidAPIKey", bundle: .module), provider)
        case let .invalidEndpoint(url):
            String(localized: "openai.error.invalidEndpoint", bundle: .module) + " (\(url))"
        case let .invalidRequest(message):
            String(localized: "openai.error.invalidRequest", bundle: .module) + " (\(message))"
        case .emptyInput:
            LLMErrorCopy.emptyInput.text
        case .imageEncodingFailed:
            LLMErrorCopy.imageEncodingFailed.text
        case let .requestFailed(error):
            LLMErrorCopy.networkError.text + " (\(error.localizedDescription))"
        case .invalidResponse:
            LLMErrorCopy.invalidResponse.text
        case .rateLimited:
            LLMErrorCopy.rateLimited.text
        case .insufficientQuota:
            String(localized: "openai.error.insufficientQuota", bundle: .module)
        case .requestTooLarge:
            LLMErrorCopy.requestTooLarge.text
        case let .serverError(code):
            String(localized: "openai.error.serverError", bundle: .module) + " (\(code))"
        case let .modelRetired(name):
            String(localized: "openai.error.modelRetired", bundle: .module) + " (\(name))"
        case .contentBlocked:
            String(localized: "openai.error.contentBlocked", bundle: .module)
        case .responseTruncated:
            LLMErrorCopy.responseTruncated.text
        }
    }

    // MARK: - Retry Classification

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .requestTooLarge:
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

    /// Transport failures may stem from an oversized image upload, and a 413
    /// certainly does, so the retry re-encodes the photos smaller.
    public var shouldCompressImagesOnRetry: Bool {
        switch self {
        case .requestFailed, .requestTooLarge: true
        default: false
        }
    }

    public var retriesOnlyWithSmallerImages: Bool {
        if case .requestTooLarge = self { return true }
        return false
    }
}
