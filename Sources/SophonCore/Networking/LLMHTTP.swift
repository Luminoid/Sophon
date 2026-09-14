//
//  LLMHTTP.swift
//  SophonCore
//
//  HTTP helpers shared by the provider clients and their error types:
//  Retry-After parsing and the transient-error classification the retry loop
//  relies on.
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

    /// RFC 9110 IMF-fixdate ("Wed, 21 Oct 2015 07:28:00 GMT"), the other form
    /// a `Retry-After` header may take.
    private static let httpDateStrategy = Date.ParseStrategy(
        // swiftlint:disable:next line_length
        format: "\(weekday: .abbreviated), \(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \(timeZone: .specificName(.short))",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt
    )

    /// Parse a `Retry-After` header, in delay-seconds or HTTP-date form, into a
    /// delay clamped to `0...cap`; nil when absent or unparseable.
    public static func retryAfterSeconds(from response: HTTPURLResponse, cap: TimeInterval) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        if let seconds = TimeInterval(raw) {
            guard seconds >= 0 else { return nil }
            return min(seconds, cap)
        }
        guard let date = try? Date(raw, strategy: httpDateStrategy) else { return nil }
        return min(max(0, date.timeIntervalSinceNow), cap)
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
