//
//  LLMDecoding.swift
//  SophonCore
//
//  Lenient decoding helpers for LLM-generated JSON, where types are unreliable:
//  strings for numbers, "null"/"none"/"n/a" for nil, percentages for floats.
//

import Foundation

/// Shared helpers for decoding LLM-generated JSON where types are unreliable.
public enum LLMDecoding {
    /// Decodes a string, treating `"null"`, `"none"`, `"n/a"`, and the empty string as `nil`.
    public static func string<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> String? {
        guard let value = try? container.decodeIfPresent(String.self, forKey: key),
              !isNullLiteral(value) else { return nil }
        return value
    }

    /// Decodes a `[String]`, falling back to a single string (or comma-separated string)
    /// when the LLM returns one. Drops null literals and empty entries. Returns nil if no
    /// usable entries remain.
    public static func stringArray<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> [String]? {
        if let array = try? container.decodeIfPresent([String].self, forKey: key) {
            let cleaned = array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !isNullLiteral($0) }
            return cleaned.isEmpty ? nil : cleaned
        }
        if let single = try? container.decodeIfPresent(String.self, forKey: key), !isNullLiteral(single) {
            let cleaned = single
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !isNullLiteral($0) }
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }

    /// Decodes an int from a JSON number, float (truncated), or parseable string.
    /// Values outside `Int` range (and NaN/infinity) decode as nil rather than trapping.
    public static func int<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        // Float → Int (handles "7.0" as JSON number)
        if let value = try? container.decode(Double.self, forKey: key) { return truncatedInt(value) }
        if let string = try? container.decode(String.self, forKey: key), !isNullLiteral(string) {
            // Try direct int parse, then float parse with truncation (handles "7.0" as string)
            if let intVal = Int(string) { return intVal }
            if let doubleVal = Double(string) { return truncatedInt(doubleVal) }
        }
        return nil
    }

    /// Truncates a double to Int, returning nil when the value has no Int representation
    /// (NaN, infinity, or magnitude beyond `Int` range). `Int(_: Double)` traps on those.
    private static func truncatedInt(_ value: Double) -> Int? {
        Int(exactly: value.rounded(.towardZero))
    }

    /// Decodes a double from a JSON number or parseable string (currency "$" stripped).
    /// Non-finite values ("inf", "nan") decode as nil.
    public static func double<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Double? {
        var value: Double?
        if let v = try? container.decode(Double.self, forKey: key) {
            value = v
        } else if let string = try? container.decode(String.self, forKey: key), !isNullLiteral(string) {
            value = Double(string.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces))
        }
        guard let value, value.isFinite else { return nil }
        return value
    }

    /// Decodes a float from a JSON number or parseable string, normalizing 0-100 percentages to 0-1.
    /// Any value above 1 is assumed to be a percentage, so an overshoot like 1.5 becomes 0.015 rather
    /// than clamping to 1; pin the range in the prompt/schema when that distinction matters.
    /// The result is clamped to 0...1 (non-finite values decode as nil), so garbage input can never
    /// escape the documented confidence range.
    public static func confidence<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Float? {
        var value: Float?
        if let v = try? container.decode(Float.self, forKey: key) {
            value = v
        } else if let string = try? container.decode(String.self, forKey: key), !isNullLiteral(string) {
            // Strip trailing "%" if present (e.g. "85%")
            let cleaned = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
            value = Float(cleaned)
        }
        guard var v = value, v.isFinite else { return nil }
        // Normalize: if > 1 assume it's a 0-100 percentage
        if v > 1 { v /= 100 }
        return min(max(v, 0), 1)
    }

    /// Whether a string is one of the null literals LLMs emit in place of JSON `null`.
    public static func isNullLiteral(_ string: String) -> Bool {
        let lowered = string.lowercased().trimmingCharacters(in: .whitespaces)
        return lowered == "null" || lowered == "none" || lowered == "n/a" || lowered.isEmpty
    }
}
