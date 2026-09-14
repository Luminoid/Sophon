//
//  LLMSchemaTests.swift
//  SophonCoreTests
//
//  Unit tests for the two schema dialects: the OpenAPI default a direct encode
//  produces (byte-compatible with Sophon 0.1/0.2) and the strict JSON Schema
//  form OpenAI and Anthropic structured outputs require.
//

import Foundation
import SophonCore
import Testing

struct LLMSchemaTests {
    private let sample = LLMSchema.object(
        properties: [
            "name": .string(description: "Plant name"),
            "confidence": .number(),
            "tags": .array(items: .string(enumValues: ["a", "b"])),
            "pot": .object(properties: ["material": .string()], required: ["material"]),
        ],
        required: ["name", "pot"],
        propertyOrdering: ["name", "confidence", "tags", "pot"]
    )

    // MARK: - OpenAPI (default)

    @Test
    func `Direct encoding defaults to the OpenAPI dialect`() throws {
        let json = try encodeToDictionary(sample)

        #expect(json["type"] as? String == "OBJECT")
        #expect(json["required"] as? [String] == ["name", "pot"])
        #expect(json["propertyOrdering"] as? [String] == ["name", "confidence", "tags", "pot"])
        #expect(json["additionalProperties"] == nil)
        let properties = try #require(json["properties"] as? [String: Any])
        #expect((properties["name"] as? [String: Any])?["type"] as? String == "STRING")
        let tags = try #require(properties["tags"] as? [String: Any])
        #expect((tags["items"] as? [String: Any])?["type"] as? String == "STRING")
    }

    @Test
    func `Encoder userInfo can select the strict dialect for direct encoding`() throws {
        let encoder = JSONEncoder()
        encoder.userInfo[LLMSchema.dialectUserInfoKey] = LLMSchemaDialect.jsonSchema
        let json = try dictionary(from: encoder.encode(sample))

        #expect(json["type"] as? String == "object")
        #expect(json["additionalProperties"] as? Bool == false)
    }

    @Test
    func `A bound document ignores encoder userInfo`() throws {
        let encoder = JSONEncoder()
        encoder.userInfo[LLMSchema.dialectUserInfoKey] = LLMSchemaDialect.jsonSchema
        let json = try dictionary(from: encoder.encode(sample.encoded(as: .openAPI)))

        #expect(json["type"] as? String == "OBJECT")
    }

    // MARK: - Strict JSON Schema

    @Test
    func `Strict dialect lowercases types and closes every object`() throws {
        let json = try encodeToDictionary(sample.encoded(as: .jsonSchema))

        #expect(json["type"] as? String == "object")
        #expect(json["additionalProperties"] as? Bool == false)
        #expect(json["propertyOrdering"] == nil)
        let properties = try #require(json["properties"] as? [String: Any])
        let pot = try #require(properties["pot"] as? [String: Any])
        #expect(pot["type"] as? String == "object")
        #expect(pot["additionalProperties"] as? Bool == false)
        #expect(pot["required"] as? [String] == ["material"])
    }

    @Test
    func `Strict dialect requires every property and makes optional ones nullable`() throws {
        let json = try encodeToDictionary(sample.encoded(as: .jsonSchema))

        #expect(json["required"] as? [String] == ["confidence", "name", "pot", "tags"])
        let properties = try #require(json["properties"] as? [String: Any])

        // Declared required: plain schema.
        let name = try #require(properties["name"] as? [String: Any])
        #expect(name["type"] as? String == "string")
        #expect(name["anyOf"] == nil)

        // Not declared required: anyOf with null.
        let confidence = try #require(properties["confidence"] as? [String: Any])
        let alternatives = try #require(confidence["anyOf"] as? [[String: Any]])
        #expect(alternatives.count == 2)
        #expect(alternatives.first?["type"] as? String == "number")
        #expect(alternatives.last?["type"] as? String == "null")
    }

    @Test
    func `Strict dialect keeps enum values and nested array items strict`() throws {
        let json = try encodeToDictionary(sample.encoded(as: .jsonSchema))
        let properties = try #require(json["properties"] as? [String: Any])
        let tags = try #require(properties["tags"] as? [String: Any])
        let inner = try #require((tags["anyOf"] as? [[String: Any]])?.first)
        #expect(inner["type"] as? String == "array")
        let items = try #require(inner["items"] as? [String: Any])
        #expect(items["type"] as? String == "string")
        #expect(items["enum"] as? [String] == ["a", "b"])
    }

    @Test
    func `Strict dialect treats a nil required list as all optional`() throws {
        let schema = LLMSchema.object(properties: ["a": .boolean(), "b": .integer()])
        let json = try encodeToDictionary(schema.encoded(as: .jsonSchema))

        #expect(json["required"] as? [String] == ["a", "b"])
        let properties = try #require(json["properties"] as? [String: Any])
        #expect((properties["a"] as? [String: Any])?["anyOf"] != nil)
        #expect((properties["b"] as? [String: Any])?["anyOf"] != nil)
    }

    @Test
    func `Scalar schemas carry descriptions in both dialects`() throws {
        let schema = LLMSchema.integer(description: "Days")
        #expect(try encodeToDictionary(schema)["description"] as? String == "Days")
        let strict = try encodeToDictionary(schema.encoded(as: .jsonSchema))
        #expect(strict["type"] as? String == "integer")
        #expect(strict["description"] as? String == "Days")
    }

    // MARK: - Helpers

    private func encodeToDictionary(_ value: some Encodable) throws -> [String: Any] {
        try dictionary(from: JSONEncoder().encode(value))
    }

    private func dictionary(from data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }
}
