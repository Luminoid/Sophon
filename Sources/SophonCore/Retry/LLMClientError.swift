//
//  LLMClientError.swift
//  SophonCore
//
//  Retry classification every provider error type exposes, so the shared retry
//  loop can drive backoff, model fallback, and image downscale without knowing
//  the provider's error cases.
//

import Foundation

public protocol LLMClientError: LocalizedError {
    /// Whether an automatic backoff retry of the same request is worth attempting.
    var isRetryable: Bool { get }
    /// Whether the provider reported the selected model as gone, so the loop
    /// should retry once on the fallback model.
    var isModelRetired: Bool { get }
    /// Whether the failure may stem from an oversized upload, so the retry
    /// should re-encode images smaller.
    var shouldCompressImagesOnRetry: Bool { get }
}
