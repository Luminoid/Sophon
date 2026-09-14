//
//  LLMRetryLoop.swift
//  SophonCore
//
//  The policy-driven send loop shared by every provider client: per-attempt
//  request variants, transient-error backoff with Retry-After, and a one-shot
//  swap to the fallback model when the provider reports the selected model as
//  retired. Runs on the caller's actor (`isolation`), so a `@MainActor` client
//  can hand in its non-Sendable closures unchanged.
//

import Foundation

public enum LLMRetryLoop {
    /// Drive `buildRequest` → `perform` → `decode` under `policy`.
    ///
    /// `buildRequest` is invoked once per attempt with the variant (image size +
    /// model ID) the loop wants for that attempt. Errors that conform to
    /// `LLMClientError` are classified for retry; any other error propagates as
    /// is, without retry. The persisted reset of a retired model selection is
    /// the provider's job (inside `decode`), which is why it happens under every
    /// policy while the in-call fallback retry is policy-gated.
    ///
    /// Pass `canDownscaleImages: false` when `buildRequest` cannot act on
    /// `useCompressedImages` (pre-encoded parts): an oversized-request error
    /// then fails immediately instead of re-sending the identical body.
    public static func run<R>(
        providerName: String,
        label: String,
        policy: LLMRetryPolicy,
        initialModelID: String,
        fallbackModelID: String,
        canDownscaleImages: Bool = true,
        isolation: isolated (any Actor)? = #isolation,
        log: (SophonLogLevel, String) -> Void,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest,
        perform: (URLRequest) async throws -> (Data, HTTPURLResponse),
        decode: (Data, HTTPURLResponse) throws -> R
    ) async throws -> R {
        var compressImages = false
        var modelID = initialModelID
        var triedFallbackModel = false
        var transientRetries = 0

        while true {
            try Task.checkCancellation()
            var lastResponse: HTTPURLResponse?
            do {
                let variant = LLMRequestVariant(useCompressedImages: compressImages, modelID: modelID)
                let request = try await buildRequest(variant)
                let (data, response) = try await perform(request)
                lastResponse = response
                return try decode(data, response)
            } catch let error as any LLMClientError {
                // Retired model: retry once against the configured fallback model.
                if policy.retriesWithFallbackModelOn404, error.isModelRetired, !triedFallbackModel,
                   fallbackModelID != modelID {
                    triedFallbackModel = true
                    modelID = fallbackModelID
                    log(.info, "\(providerName) \(label): retrying with fallback model \(modelID)")
                    continue
                }

                // Transient (429 / 5xx / timeout / too large): exponential backoff, bounded retries.
                if error.isRetryable, transientRetries < policy.maxRetries {
                    let downscales = policy.downscalesImagesOnRetry && canDownscaleImages
                        && error.shouldCompressImagesOnRetry && !compressImages
                    // A 413 is only worth re-sending with smaller images; an
                    // identical body would just fail again.
                    if error.retriesOnlyWithSmallerImages, !downscales {
                        throw error
                    }
                    transientRetries += 1
                    if downscales {
                        compressImages = true
                    }
                    if error.retriesOnlyWithSmallerImages {
                        log(.info, "\(providerName) \(label): request too large, retry \(transientRetries)/\(policy.maxRetries) with smaller images")
                        continue
                    }
                    let retryAfter = lastResponse.flatMap { LLMHTTP.retryAfterSeconds(from: $0, cap: policy.maxDelay) }
                    let delay = max(0, policy.backoffDelay(retry: transientRetries, retryAfter: retryAfter))
                    log(.info, "\(providerName) \(label): transient error, retry \(transientRetries)/\(policy.maxRetries) in \(String(format: "%.1f", delay))s")
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }

                throw error
            }
        }
    }
}
