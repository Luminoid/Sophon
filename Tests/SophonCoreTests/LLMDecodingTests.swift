//
//  LLMDecodingTests.swift
//  SophonCoreTests
//
//  Unit tests for the lenient LLM JSON decoding helpers.
//

import Foundation
import SophonCore
import Testing

struct LLMDecodingTests {
    // MARK: - String

    @Test
    func `string returns valid string`() throws {
        let container = try decodeContainer(from: Data(#"{"name": "Snake Plant"}"#.utf8))
        #expect(LLMDecoding.string(from: container, key: .name) == "Snake Plant")
    }

    @Test
    func `string treats 'null' literal as nil`() throws {
        let container = try decodeContainer(from: Data(#"{"name": "null"}"#.utf8))
        #expect(LLMDecoding.string(from: container, key: .name) == nil)
    }

    @Test
    func `string treats 'none' as nil`() throws {
        let container = try decodeContainer(from: Data(#"{"name": "none"}"#.utf8))
        #expect(LLMDecoding.string(from: container, key: .name) == nil)
    }

    @Test
    func `string treats 'n/a' as nil`() throws {
        let container = try decodeContainer(from: Data(#"{"name": "N/A"}"#.utf8))
        #expect(LLMDecoding.string(from: container, key: .name) == nil)
    }

    @Test
    func `string treats empty string as nil`() throws {
        let container = try decodeContainer(from: Data(#"{"name": ""}"#.utf8))
        #expect(LLMDecoding.string(from: container, key: .name) == nil)
    }

    // MARK: - String Array

    @Test
    func `stringArray decodes array and drops null literals`() throws {
        let container = try decodeContainer(from: Data(#"{"methods": ["division", "null", " cuttings ", ""]}"#.utf8))
        #expect(LLMDecoding.stringArray(from: container, key: .methods) == ["division", "cuttings"])
    }

    @Test
    func `stringArray falls back to comma-separated single string`() throws {
        let container = try decodeContainer(from: Data(#"{"methods": "division, cuttings"}"#.utf8))
        #expect(LLMDecoding.stringArray(from: container, key: .methods) == ["division", "cuttings"])
    }

    @Test
    func `stringArray returns nil when nothing usable remains`() throws {
        let container = try decodeContainer(from: Data(#"{"methods": ["null", "n/a"]}"#.utf8))
        #expect(LLMDecoding.stringArray(from: container, key: .methods) == nil)
    }

    // MARK: - Int

    @Test
    func `int from integer`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": 7}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == 7)
    }

    @Test
    func `int from float truncates`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": 7.5}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == 7)
    }

    @Test
    func `int from string`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": "7"}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == 7)
    }

    @Test
    func `int from float string`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": "7.0"}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == 7)
    }

    @Test
    func `int from null literal string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": "null"}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == nil)
    }

    @Test
    func `int from float beyond Int.max returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": 1e30}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == nil)
    }

    @Test
    func `int from float below Int.min returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": -1e30}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == nil)
    }

    @Test
    func `int from out-of-range float string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": "1e30"}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == nil)
    }

    @Test
    func `int from infinity string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": "inf"}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == nil)
    }

    @Test
    func `int from nan string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"interval": "nan"}"#.utf8))
        #expect(LLMDecoding.int(from: container, key: .interval) == nil)
    }

    // MARK: - Double

    @Test
    func `double from number`() throws {
        let container = try decodeContainer(from: Data(#"{"cost": 142.5}"#.utf8))
        #expect(LLMDecoding.double(from: container, key: .cost) == 142.5)
    }

    @Test
    func `double from currency string strips dollar sign`() throws {
        let container = try decodeContainer(from: Data(#"{"cost": "$142.50"}"#.utf8))
        #expect(LLMDecoding.double(from: container, key: .cost) == 142.5)
    }

    @Test
    func `double from null literal returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"cost": "n/a"}"#.utf8))
        #expect(LLMDecoding.double(from: container, key: .cost) == nil)
    }

    @Test
    func `double from infinity string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"cost": "inf"}"#.utf8))
        #expect(LLMDecoding.double(from: container, key: .cost) == nil)
    }

    @Test
    func `double from nan string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"cost": "nan"}"#.utf8))
        #expect(LLMDecoding.double(from: container, key: .cost) == nil)
    }

    // MARK: - Confidence

    @Test
    func `confidence from float`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": 0.85}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == 0.85)
    }

    @Test
    func `confidence normalizes percentage`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": 85}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == 0.85)
    }

    @Test
    func `confidence from string`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": "0.9"}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == 0.9)
    }

    @Test
    func `confidence from percentage string with %`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": "85%"}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == 0.85)
    }

    @Test
    func `confidence clamps negative to zero`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": -0.5}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == 0)
    }

    @Test
    func `confidence clamps garbage overshoot to one`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": 12345}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == 1)
    }

    @Test
    func `confidence from infinity string returns nil`() throws {
        let container = try decodeContainer(from: Data(#"{"confidence": "inf"}"#.utf8))
        #expect(LLMDecoding.confidence(from: container, key: .confidence) == nil)
    }

    // MARK: - Helpers

    private enum TestCodingKeys: String, CodingKey {
        case name, methods, interval, cost, confidence
    }

    private func decodeContainer(from data: Data) throws -> KeyedDecodingContainer<TestCodingKeys> {
        try JSONDecoder().decode(TestWrapper.self, from: data).container
    }

    private struct TestWrapper: Decodable {
        let container: KeyedDecodingContainer<TestCodingKeys>

        init(from decoder: any Decoder) throws {
            container = try decoder.container(keyedBy: TestCodingKeys.self)
        }
    }
}
