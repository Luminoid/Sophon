//
//  LLMErrorCopy.swift
//  SophonCore
//
//  User-facing copy for the error cases every provider shares (parse failures,
//  rate limits, transport errors, ...), resolved once from SophonCore's own
//  string bundle so the provider targets only carry their provider-flavored
//  lines. Classic `.lproj/Localizable.strings`, like the provider targets.
//

import Foundation

public enum LLMErrorCopy: Sendable {
    case invalidResponse
    case rateLimited
    case networkError
    case imageEncodingFailed
    case emptyInput
    case responseTruncated
    case requestTooLarge
    case apiKeyInaccessible

    /// The localized sentence for the case.
    public var text: String {
        switch self {
        case .invalidResponse:
            String(localized: "llm.error.invalidResponse", bundle: .module)
        case .rateLimited:
            String(localized: "llm.error.rateLimited", bundle: .module)
        case .networkError:
            String(localized: "llm.error.networkError", bundle: .module)
        case .imageEncodingFailed:
            String(localized: "llm.error.imageEncodingFailed", bundle: .module)
        case .emptyInput:
            String(localized: "llm.error.emptyInput", bundle: .module)
        case .responseTruncated:
            String(localized: "llm.error.responseTruncated", bundle: .module)
        case .requestTooLarge:
            String(localized: "llm.error.requestTooLarge", bundle: .module)
        case .apiKeyInaccessible:
            String(localized: "llm.error.apiKeyInaccessible", bundle: .module)
        }
    }
}
