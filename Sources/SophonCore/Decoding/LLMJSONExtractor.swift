//
//  LLMJSONExtractor.swift
//  SophonCore
//
//  Extraction and repair of JSON embedded in LLM text output: markdown fences,
//  leading prose, and truncation cut-offs.
//

import Foundation

public enum LLMJSONExtractor {
    /// Strip markdown fences and leading/trailing prose around a JSON payload.
    /// Returns the input unchanged when no embedded JSON structure is found.
    public static func extractJSON(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("```json") {
            result = String(result.dropFirst(7))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("{") || result.hasPrefix("[") {
            return result
        }

        if let jsonString = extractOutermostBraces(from: result) {
            return jsonString
        }

        return result
    }

    /// Extract the outermost balanced `{...}` or `[...]` from mixed text, honoring
    /// string literals and escapes. Returns nil when no balanced structure exists.
    public static func extractOutermostBraces(from text: String) -> String? {
        let openChars: Set<Character> = ["{", "["]
        let closeMap: [Character: Character] = ["{": "}", "[": "]"]
        guard let startIndex = text.firstIndex(where: { openChars.contains($0) }) else { return nil }
        let openChar = text[startIndex]
        guard let expectedClose = closeMap[openChar] else { return nil }

        var depth = 0
        var inString = false
        var escaped = false

        for index in text[startIndex...].indices {
            let char = text[index]
            if escaped { escaped = false; continue }
            if char == "\\", inString { escaped = true; continue }
            if char == "\"" { inString.toggle(); continue }
            guard !inString else { continue }
            if char == openChar {
                depth += 1
            } else if char == expectedClose {
                depth -= 1
                if depth == 0 {
                    return String(text[startIndex ... index])
                }
            }
        }
        return nil
    }

    /// Best-effort repair of JSON cut off mid-structure: closes a dangling string, drops a
    /// trailing comma, then appends the unbalanced closing braces/brackets. Returns nil when
    /// there is nothing to repair.
    public static func repairTruncatedJSON(_ text: String) -> String? {
        var stack: [Character] = []
        var inString = false
        var escaped = false
        for char in text {
            if escaped { escaped = false; continue }
            if inString {
                if char == "\\" { escaped = true } else if char == "\"" { inString = false }
                continue
            }
            switch char {
            case "\"": inString = true
            case "{": stack.append("}")
            case "[": stack.append("]")
            case "}", "]": if stack.last == char { stack.removeLast() }
            default: break
            }
        }
        guard inString || !stack.isEmpty else { return nil }

        var repaired = text
        if inString {
            repaired.append("\"")
        } else {
            while let last = repaired.last, last == " " || last == "\n" || last == "\t" || last == "\r" {
                repaired.removeLast()
            }
            if repaired.last == "," { repaired.removeLast() }
        }
        while let closer = stack.popLast() {
            repaired.append(closer)
        }
        return repaired
    }

    /// Human-readable summary of a `DecodingError` for log lines.
    public static func decodingErrorDetail(_ error: Error) -> String {
        switch error {
        case let decodingError as DecodingError:
            switch decodingError {
            case let .keyNotFound(key, context):
                "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case let .typeMismatch(type, context):
                "Type mismatch: expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case let .valueNotFound(type, context):
                "Null value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case let .dataCorrupted(context):
                "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
            @unknown default:
                "Unknown decoding error"
            }
        default:
            error.localizedDescription
        }
    }
}
