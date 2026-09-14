//
//  GeminiError.swift
//  SophonGemini
//
//  Errors surfaced by the Gemini request pipeline, with retry classification.
//  User-facing copy resolves from the package's string catalog; apps wanting
//  feature-specific wording map cases at their feature layer.
//

import Foundation
import SophonCore

public enum GeminiError: LLMClientError {
    case apiKeyMissing
    case invalidAPIKey
    /// The model identifier could not form a valid request URL (carries the offending ID).
    case invalidModelID(String)
    /// The caller had nothing to send (empty text input). Thrown by app services, not the client.
    case emptyInput
    case imageEncodingFailed
    case requestFailed(Error)
    case invalidResponse
    case rateLimited
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
        case .invalidAPIKey:
            String(localized: "gemini.error.invalidAPIKey", bundle: .module)
        case let .invalidModelID(id):
            String(localized: "gemini.error.invalidModelID", bundle: .module) + " (\(id))"
        case .emptyInput:
            String(localized: "gemini.error.emptyInput", bundle: .module)
        case .imageEncodingFailed:
            String(localized: "gemini.error.imageEncodingFailed", bundle: .module)
        case let .requestFailed(error):
            String(localized: "gemini.error.networkError", bundle: .module) + " (\(error.localizedDescription))"
        case .invalidResponse:
            String(localized: "gemini.error.invalidResponse", bundle: .module)
        case .rateLimited:
            String(localized: "gemini.error.rateLimited", bundle: .module)
        case let .serverError(code):
            String(localized: "gemini.error.serverError", bundle: .module) + " (\(code))"
        case let .modelRetired(name):
            String(localized: "gemini.error.modelRetired", bundle: .module) + " (\(name))"
        case .contentBlocked:
            String(localized: "gemini.error.contentBlocked", bundle: .module)
        case .responseTruncated:
            String(localized: "gemini.error.responseTruncated", bundle: .module)
        }
    }

    // MARK: - Retry Classification

    /// Whether an automatic backoff retry of the same request is worth attempting.
    /// Transient HTTP statuses (429, 5xx, 408) and recoverable network failures qualify;
    /// permanent errors (bad key, blocked content, malformed parse) do not.
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

    /// A 404 from the API means the selected model is retired; with the default
    /// retry policy the client retries once against the configured fallback model
    /// rather than failing the user's action.
    public var isModelRetired: Bool {
        if case .modelRetired = self { return true }
        return false
    }

    /// Network/transport failures may stem from an oversized image upload, so the retry
    /// re-encodes the photos smaller. HTTP-level transient errors do not need this.
    public var shouldCompressImagesOnRetry: Bool {
        if case .requestFailed = self { return true }
        return false
    }
}
