//
//  GeminiSchemaTests.swift
//  SophonGeminiTests
//
//  Unit tests for GeminiSchema encoding and GeminiGenerationConfig with responseSchema.
//

import Foundation
import SophonGemini
import Testing

struct GeminiSchemaTests {
    // MARK: - Encoding

    @Test
    func `String schema encodes type correctly`() throws {
        let schema = GeminiSchema.string(description: "A name")
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "STRING")
        #expect(json["description"] as? String == "A name")
    }

    @Test
    func `String schema with enum values encodes correctly`() throws {
        let schema = GeminiSchema.string(enumValues: ["low", "medium", "high"])
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "STRING")
        let enumValues = json["enum"] as? [String]
        #expect(enumValues == ["low", "medium", "high"])
    }

    @Test
    func `Integer schema encodes type correctly`() throws {
        let schema = GeminiSchema.integer(description: "Days count")
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "INTEGER")
        #expect(json["description"] as? String == "Days count")
    }

    @Test
    func `Number schema encodes type correctly`() throws {
        let schema = GeminiSchema.number()
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "NUMBER")
    }

    @Test
    func `Boolean schema encodes type correctly`() throws {
        let schema = GeminiSchema.boolean()
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "BOOLEAN")
    }

    @Test
    func `Object schema encodes properties and required fields`() throws {
        let schema = GeminiSchema.object(
            properties: [
                "name": .string(description: "Plant name"),
                "confidence": .number(),
            ],
            required: ["name"]
        )
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "OBJECT")
        let properties = json["properties"] as? [String: Any]
        #expect(properties?.count == 2)
        #expect(properties?["name"] != nil)
        #expect(properties?["confidence"] != nil)
        #expect(json["required"] as? [String] == ["name"])
    }

    @Test
    func `Object schema omits required when nil`() throws {
        let schema = GeminiSchema.object(properties: ["name": .string()])
        let json = try encodeToDictionary(schema)

        #expect(json["required"] == nil)
    }

    @Test
    func `Object schema encodes propertyOrdering`() throws {
        let schema = GeminiSchema.object(
            properties: [
                "days": .array(items: .string()),
                "title": .string(),
            ],
            propertyOrdering: ["title", "days"]
        )
        let json = try encodeToDictionary(schema)

        #expect(json["propertyOrdering"] as? [String] == ["title", "days"])
    }

    @Test
    func `Object schema omits propertyOrdering when nil or empty`() throws {
        let none = try encodeToDictionary(GeminiSchema.object(properties: ["a": .string()]))
        #expect(none["propertyOrdering"] == nil)

        let empty = try encodeToDictionary(GeminiSchema.object(properties: ["a": .string()], propertyOrdering: []))
        #expect(empty["propertyOrdering"] == nil)
    }

    @Test
    func `Array schema encodes items`() throws {
        let schema = GeminiSchema.array(
            items: .object(properties: ["material": .string()]),
            description: "Soil layers"
        )
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "ARRAY")
        #expect(json["description"] as? String == "Soil layers")
        let items = json["items"] as? [String: Any]
        #expect(items?["type"] as? String == "OBJECT")
    }

    @Test
    func `String schema without description or enum omits those keys`() throws {
        let schema = GeminiSchema.string()
        let json = try encodeToDictionary(schema)

        #expect(json["type"] as? String == "STRING")
        #expect(json["description"] == nil)
        #expect(json["enum"] == nil)
    }

    @Test
    func `Nested object schema encodes correctly`() throws {
        let schema = GeminiSchema.object(
            properties: [
                "pot": .object(properties: [
                    "materialType": .string(enumValues: ["plastic", "terracotta"]),
                    "hasDrainageHole": .boolean(),
                ]),
            ]
        )
        let json = try encodeToDictionary(schema)
        let properties = json["properties"] as? [String: Any]
        let pot = properties?["pot"] as? [String: Any]
        #expect(pot?["type"] as? String == "OBJECT")
        let potProperties = pot?["properties"] as? [String: Any]
        #expect(potProperties?.count == 2)
    }

    // MARK: - GeminiGenerationConfig

    @Test
    func `GenerationConfig encodes responseSchema when provided`() throws {
        let config = GeminiGenerationConfig(
            responseMimeType: "application/json",
            temperature: 0.1,
            responseSchema: .object(properties: ["name": .string()], required: ["name"])
        )
        let json = try encodeToDictionary(config)

        #expect(json["response_mime_type"] as? String == "application/json")
        #expect(json["temperature"] as? Double == 0.1)
        let schema = json["response_schema"] as? [String: Any]
        #expect(schema?["type"] as? String == "OBJECT")
    }

    @Test
    func `GenerationConfig omits responseSchema when nil`() throws {
        let config = GeminiGenerationConfig(
            responseMimeType: "application/json",
            temperature: 0.1
        )
        let json = try encodeToDictionary(config)

        #expect(json["response_schema"] == nil)
    }

    // MARK: - Helpers

    private func encodeToDictionary(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw TestError.invalidJSON
        }
        return dict
    }

    private enum TestError: Error {
        case invalidJSON
    }
}
