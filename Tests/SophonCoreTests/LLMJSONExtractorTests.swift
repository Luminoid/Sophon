//
//  LLMJSONExtractorTests.swift
//  SophonCoreTests
//
//  Unit tests for JSON extraction from LLM text output and truncation repair.
//

import Foundation
import SophonCore
import Testing

struct LLMJSONExtractorTests {
    // MARK: - extractJSON

    @Test
    func `extractJSON strips json markdown fence`() {
        let text = "```json\n{\"name\": \"Fern\"}\n```"
        #expect(LLMJSONExtractor.extractJSON(from: text) == "{\"name\": \"Fern\"}")
    }

    @Test
    func `extractJSON strips plain markdown fence`() {
        let text = "```\n{\"name\": \"Fern\"}\n```"
        #expect(LLMJSONExtractor.extractJSON(from: text) == "{\"name\": \"Fern\"}")
    }

    @Test
    func `extractJSON pulls object out of leading prose`() {
        let text = "Here is the result: {\"name\": \"Cactus\"} hope it helps"
        #expect(LLMJSONExtractor.extractJSON(from: text) == "{\"name\": \"Cactus\"}")
    }

    @Test
    func `extractJSON passes bare object through`() {
        #expect(LLMJSONExtractor.extractJSON(from: " {\"a\": 1} ") == "{\"a\": 1}")
    }

    @Test
    func `extractJSON passes bare array through`() {
        #expect(LLMJSONExtractor.extractJSON(from: "[1, 2]") == "[1, 2]")
    }

    @Test
    func `extractJSON returns input when no JSON found`() {
        #expect(LLMJSONExtractor.extractJSON(from: "no json here") == "no json here")
    }

    // MARK: - extractOutermostBraces

    @Test
    func `extractOutermostBraces handles nesting`() {
        let text = "x {\"a\": {\"b\": 1}} y"
        #expect(LLMJSONExtractor.extractOutermostBraces(from: text) == "{\"a\": {\"b\": 1}}")
    }

    @Test
    func `extractOutermostBraces ignores braces inside strings`() {
        let text = "{\"a\": \"}{\"}"
        #expect(LLMJSONExtractor.extractOutermostBraces(from: text) == "{\"a\": \"}{\"}")
    }

    @Test
    func `extractOutermostBraces returns nil for unbalanced text`() {
        #expect(LLMJSONExtractor.extractOutermostBraces(from: "{\"a\": 1") == nil)
    }

    // MARK: - repairTruncatedJSON

    @Test
    func `repairTruncatedJSON closes unbalanced structures`() {
        let openObject = "{\"name\":\"Snake Plant\",\"confidence\":0.9"
        let openObjectFixed = "{\"name\":\"Snake Plant\",\"confidence\":0.9}"
        #expect(LLMJSONExtractor.repairTruncatedJSON(openObject) == openObjectFixed)

        #expect(LLMJSONExtractor.repairTruncatedJSON("{\"a\":1,") == "{\"a\":1}")
        #expect(LLMJSONExtractor.repairTruncatedJSON("{\"a\":\"hel") == "{\"a\":\"hel\"}")
        // Complete JSON needs no repair.
        #expect(LLMJSONExtractor.repairTruncatedJSON("{\"a\":1}") == nil)
    }

    @Test
    func `repairTruncatedJSON closes nested arrays and objects`() {
        #expect(LLMJSONExtractor.repairTruncatedJSON("{\"a\":[{\"b\":1") == "{\"a\":[{\"b\":1}]}")
    }

    // MARK: - decodingErrorDetail

    @Test
    func `decodingErrorDetail formats key not found`() {
        let error = DecodingError.keyNotFound(
            TestCodingKey(stringValue: "name"),
            .init(codingPath: [], debugDescription: "missing")
        )
        #expect(LLMJSONExtractor.decodingErrorDetail(error).contains("name"))
    }

    private struct TestCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}
