//
//  GeminiResponseTests.swift
//  SophonGeminiTests
//
//  Unit tests for GeminiResponse parsing: text extraction, block reasons, and
//  truncation detection.
//

import Foundation
import SophonGemini
import Testing

struct GeminiResponseTests {
    @Test
    func `extracts text from candidates`() throws {
        let json = Data("""
        {
            "candidates": [{
                "content": {
                    "parts": [{"text": "{\\"name\\": \\"Fern\\"}"}]
                }
            }]
        }
        """.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: json)

        #expect(response.extractedText == #"{"name": "Fern"}"#)
    }

    @Test
    func `returns nil for empty candidates`() throws {
        let response = try JSONDecoder().decode(GeminiResponse.self, from: Data(#"{"candidates": []}"#.utf8))
        #expect(response.extractedText == nil)
    }

    @Test
    func `parses API error`() throws {
        let json = Data(#"{"error": {"message": "API key invalid", "code": 403}}"#.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: json)

        #expect(response.error?.message == "API key invalid")
        #expect(response.error?.code == 403)
    }

    @Test
    func `blockReason surfaces prompt feedback`() throws {
        let json = Data(#"{"promptFeedback": {"blockReason": "SAFETY"}}"#.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: json)

        #expect(response.blockReason == "SAFETY")
    }

    @Test
    func `blockReason surfaces blocking finish reasons`() throws {
        let json = Data(#"{"candidates": [{"finishReason": "RECITATION"}]}"#.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: json)

        #expect(response.blockReason == "RECITATION")
    }

    @Test
    func `STOP finish reason is not a block`() throws {
        let json = Data(#"{"candidates": [{"content": {"parts": [{"text": "ok"}]}, "finishReason": "STOP"}]}"#.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: json)

        #expect(response.blockReason == nil)
        #expect(!response.isTruncated)
    }

    @Test
    func `MAX_TOKENS finish reason marks truncation`() throws {
        let json = Data(#"{"candidates": [{"content": {"parts": [{"text": "partial"}]}, "finishReason": "MAX_TOKENS"}]}"#.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: json)

        #expect(response.isTruncated)
    }
}
