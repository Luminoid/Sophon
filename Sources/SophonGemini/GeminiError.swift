//
//  GeminiError.swift
//  SophonGemini
//
//  Errors surfaced by the Gemini request pipeline, with retry classification.
//  Gemini-flavored copy resolves from this target's strings; the cases every
//  provider shares read from `LLMErrorCopy` in SophonCore. Apps wanting
//  feature-specific wording map cases at their feature layer.
//

import Foundation
import SophonCore

public enum GeminiError: LLMClientError {
    case apiKeyMissing
    /// The Keychain refused to hand over the stored key (device locked); carries the OSStatus.
    case apiKeyInaccessible(OSStatus)
    case invalidAPIKey
    /// The model identifier could not form a valid request URL (carries the offending ID).
    case invalidModelID(String)
    /// Gemini rejected the request (HTTP 400); carries the API's message.
    case invalidRequest(String)
    /// The caller had nothing to send (empty text input). Thrown by app services, not the client.
    case emptyInput
    case imageEncodingFailed
    case requestFailed(Error)
    case invalidResponse
    case rateLimited
    /// HTTP 413: the request body is too large. Retried with smaller images
    /// when the request builder can re-encode them; fails at once otherwise.
    case requestTooLarge
    case serverError(Int)
    case modelRetired(String)
    /// Gemini refused the request on safety/recitation grounds (carries the block reason).
    case contentBlocked(String)
    /// Gemini hit its output-token limit, so the response is incomplete.
    case responseTruncated

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            String(localized: "gemini.error.apiKeyMissing", bundle: .module)
        case .apiKeyInaccessible:
            LLMErrorCopy.apiKeyInaccessible.text
        case .invalidAPIKey:
            String(localized: "gemini.error.invalidAPIKey", bundle: .module)
        case let .invalidModelID(id):
            String(localized: "gemini.error.invalidModelID", bundle: .module) + " (\(id))"
        case let .invalidRequest(message):
            String(localized: "gemini.error.invalidRequest", bundle: .module) + " (\(message))"
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
        case .requestTooLarge:
            LLMErrorCopy.requestTooLarge.text
        case let .serverError(code):
            String(localized: "gemini.error.serverError", bundle: .module) + " (\(code))"
        case let .modelRetired(name):
            String(localized: "gemini.error.modelRetired", bundle: .module) + " (\(name))"
        case .contentBlocked:
            String(localized: "gemini.error.contentBlocked", bundle: .module)
        case .responseTruncated:
            LLMErrorCopy.responseTruncated.text
        }
    }

    // MARK: - Retry Classification

    /// Whether an automatic backoff retry of the same request is worth attempting.
    /// Transient HTTP statuses (429, 5xx, 408), recoverable network failures, and
    /// an oversized request (re-sent with smaller images) qualify; permanent
    /// errors (bad key, blocked content, malformed parse) do not.
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

    /// A 404 from the API means the selected model is retired; with the default
    /// retry policy the client retries once against the configured fallback model
    /// rather than failing the user's action.
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
