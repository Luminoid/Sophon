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
    public static func int<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        // Float → Int (handles "7.0" as JSON number)
        if let value = try? container.decode(Double.self, forKey: key) { return Int(value) }
        if let string = try? container.decode(String.self, forKey: key), !isNullLiteral(string) {
            // Try direct int parse, then float parse with truncation (handles "7.0" as string)
            if let intVal = Int(string) { return intVal }
            if let doubleVal = Double(string) { return Int(doubleVal) }
        }
        return nil
    }

    /// Decodes a double from a JSON number or parseable string (currency "$" stripped).
    public static func double<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let string = try? container.decode(String.self, forKey: key), !isNullLiteral(string) {
            return Double(string.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Decodes a float from a JSON number or parseable string, normalizing 0-100 percentages to 0-1.
    public static func confidence<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Float? {
        var value: Float?
        if let v = try? container.decode(Float.self, forKey: key) {
            value = v
        } else if let string = try? container.decode(String.self, forKey: key), !isNullLiteral(string) {
            // Strip trailing "%" if present (e.g. "85%")
            let cleaned = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
            value = Float(cleaned)
        }
        // Normalize: if > 1 assume it's a 0-100 percentage
        if let v = value, v > 1 { value = v / 100 }
        return value
    }

    /// Whether a string is one of the null literals LLMs emit in place of JSON `null`.
    public static func isNullLiteral(_ string: String) -> Bool {
        let lowered = string.lowercased().trimmingCharacters(in: .whitespaces)
        return lowered == "null" || lowered == "none" || lowered == "n/a" || lowered.isEmpty
    }
}
