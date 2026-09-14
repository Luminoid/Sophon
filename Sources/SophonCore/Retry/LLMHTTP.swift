//
//  LLMHTTP.swift
//  SophonCore
//
//  HTTP helpers shared by the provider clients: Retry-After parsing and the
//  transient-error classification the retry loop relies on.
//

import Foundation

public enum LLMHTTP {
    /// HTTP statuses worth an automatic backoff retry.
    public static let retryableServerCodes: Set<Int> = [408, 425, 429, 500, 502, 503, 504]

    private static let retryableURLErrorCodes: Set<Int> = [
        NSURLErrorTimedOut,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorCannotFindHost,
        NSURLErrorDNSLookupFailed,
        NSURLErrorNotConnectedToInternet,
        NSURLErrorResourceUnavailable,
        NSURLErrorRequestBodyStreamExhausted,
    ]

    /// Parse a numeric `Retry-After` header into a delay clamped to `cap`, or nil if absent/invalid.
    public static func retryAfterSeconds(from response: HTTPURLResponse, cap: TimeInterval) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces),
              let seconds = TimeInterval(raw), seconds >= 0 else {
            return nil
        }
        return min(seconds, cap)
    }

    public static func isRetryableServerCode(_ code: Int) -> Bool {
        retryableServerCodes.contains(code)
    }

    /// Recoverable transport failures (timeouts, lost connections, DNS) qualify
    /// for a retry; cancellations and TLS/policy failures do not.
    public static func isRetryableURLError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return retryableURLErrorCodes.contains(nsError.code)
    }
}
