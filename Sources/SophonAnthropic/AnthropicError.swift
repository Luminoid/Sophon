//
//  AnthropicError.swift
//  SophonAnthropic
//
//  Errors surfaced by the Messages API request pipeline, with retry
//  classification. Claude-flavored copy resolves from this target's strings;
//  the cases every provider shares read from `LLMErrorCopy` in SophonCore.
//  Apps wanting feature-specific wording map cases at their feature layer.
//

import Foundation
import SophonCore

public enum AnthropicError: LLMClientError {
    case apiKeyMissing
    /// The Keychain refused to hand over the stored key (device locked); carries the OSStatus.
    case apiKeyInaccessible(OSStatus)
    case invalidAPIKey
    /// The base URL and path could not form a request URL (carries the offending string).
    case invalidEndpoint(String)
    /// The API rejected the request (HTTP 400); carries the API's message.
    case invalidRequest(String)
    /// The caller had nothing to send (empty text input). Thrown by app services, not the client.
    case emptyInput
    case imageEncodingFailed
    case requestFailed(Error)
    case invalidResponse
    case rateLimited
    /// The account's credit balance is exhausted (a 400 whose message says so). Not retryable.
    case insufficientQuota
    /// HTTP 529: the API is temporarily overloaded. Retryable.
    case overloaded
    /// HTTP 413: the request body is too large. Retried with smaller images
    /// when the request builder can re-encode them; fails at once otherwise.
    case requestTooLarge
    case serverError(Int)
    case modelRetired(String)
    /// Claude declined the request (`stop_reason: refusal`).
    case contentBlocked(String)
    /// The response hit `max_tokens`, so it is incomplete.
    case responseTruncated

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            String(localized: "anthropic.error.apiKeyMissing", bundle: .module)
        case .apiKeyInaccessible:
            LLMErrorCopy.apiKeyInaccessible.text
        case .invalidAPIKey:
            String(localized: "anthropic.error.invalidAPIKey", bundle: .module)
        case let .invalidEndpoint(url):
            String(localized: "anthropic.error.invalidEndpoint", bundle: .module) + " (\(url))"
        case let .invalidRequest(message):
            String(localized: "anthropic.error.invalidRequest", bundle: .module) + " (\(message))"
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
            String(localized: "anthropic.error.insufficientQuota", bundle: .module)
        case .overloaded:
            String(localized: "anthropic.error.overloaded", bundle: .module)
        case .requestTooLarge:
            LLMErrorCopy.requestTooLarge.text
        case let .serverError(code):
            String(localized: "anthropic.error.serverError", bundle: .module) + " (\(code))"
        case let .modelRetired(name):
            String(localized: "anthropic.error.modelRetired", bundle: .module) + " (\(name))"
        case .contentBlocked:
            String(localized: "anthropic.error.contentBlocked", bundle: .module)
        case .responseTruncated:
            LLMErrorCopy.responseTruncated.text
        }
    }

    // MARK: - Retry Classification

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .overloaded, .requestTooLarge:
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

    /// Transport failures and an explicit 413 both point at oversized uploads.
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
