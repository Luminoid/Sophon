//
//  GeminiRetryPolicy.swift
//  SophonGemini
//
//  Caller-controlled retry behavior. `.default` is the full loop (Retry-After,
//  jitter, same-call 404 model fallback, image downscale on retry); `.minimal`
//  is plain fixed exponential backoff, so adopting the richer loop is a
//  deliberate choice.
//

import Foundation

public struct GeminiRetryPolicy: Sendable {
    /// Total attempts including the first; 1 disables retries.
    public var maxAttempts: Int
    /// Exponential-backoff base delay (seconds); doubles each retry.
    public var baseDelay: TimeInterval
    /// Upper bound for a single backoff wait (seconds), also caps an honored Retry-After.
    public var maxDelay: TimeInterval
    /// Whether a numeric `Retry-After` response header overrides the computed backoff.
    public var honorsRetryAfter: Bool
    /// Whether a small deterministic jitter (0-20% of the delay) de-correlates retries.
    public var usesJitter: Bool
    /// Whether a 404 (retired model) retries once against the fallback model within the same call.
    public var retriesWithFallbackModelOn404: Bool
    /// Whether a transport failure re-encodes images smaller before retrying.
    public var downscalesImagesOnRetry: Bool

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.8,
        maxDelay: TimeInterval = 6.0,
        honorsRetryAfter: Bool = true,
        usesJitter: Bool = true,
        retriesWithFallbackModelOn404: Bool = true,
        downscalesImagesOnRetry: Bool = true
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.honorsRetryAfter = honorsRetryAfter
        self.usesJitter = usesJitter
        self.retriesWithFallbackModelOn404 = retriesWithFallbackModelOn404
        self.downscalesImagesOnRetry = downscalesImagesOnRetry
    }

    /// The full loop: Retry-After honoring, jitter, same-call 404 fallback,
    /// image downscale on transport failure.
    public static let `default` = Self()

    /// Fixed exponential backoff on transient errors only. A 404 still resets
    /// the persisted model selection but the in-flight call fails.
    public static let minimal = Self(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 6.0,
        honorsRetryAfter: false,
        usesJitter: false,
        retriesWithFallbackModelOn404: false,
        downscalesImagesOnRetry: false
    )

    /// Max automatic retries on transient errors. Total attempts = maxRetries + 1.
    public var maxRetries: Int {
        max(0, maxAttempts - 1)
    }

    /// Exponential backoff capped at `maxDelay`, with optional deterministic jitter.
    /// Honors a server `Retry-After` (already parsed to seconds) when enabled.
    public func backoffDelay(retry: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if honorsRetryAfter, let retryAfter { return min(retryAfter, maxDelay) }
        let exponential = baseDelay * pow(2.0, Double(max(0, retry - 1)))
        let capped = min(exponential, maxDelay)
        // Deterministic jitter (0...20% of the delay) to de-correlate retries without Math.random.
        let jitter = usesJitter ? capped * 0.2 * (Double(retry % 3) / 2.0) : 0
        return min(capped + jitter, maxDelay)
    }
}
