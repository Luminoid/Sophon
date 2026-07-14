//
//  GeminiSchema.swift
//  SophonGemini
//
//  JSON Schema type for Gemini's `responseSchema` field in `generationConfig`.
//

import Foundation

/// JSON Schema type for Gemini's `responseSchema` field in `generationConfig`.
/// When provided, the API guarantees the response matches the declared structure.
public indirect enum GeminiSchema: Encodable, Sendable {
    case object(properties: [String: Self], required: [String]? = nil, propertyOrdering: [String]? = nil, description: String? = nil)
    case array(items: Self, description: String? = nil)
    case string(description: String? = nil, enumValues: [String]? = nil)
    case number(description: String? = nil)
    case integer(description: String? = nil)
    case boolean(description: String? = nil)

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: SchemaCodingKeys.self)

        switch self {
        case let .object(properties, required, propertyOrdering, description):
            try container.encode("OBJECT", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            try container.encode(properties, forKey: .properties)
            if let required, !required.isEmpty {
                try container.encode(required, forKey: .required)
            }
            // Dictionaries encode in random order, so without an explicit
            // ordering the model generates fields in an arbitrary sequence.
            if let propertyOrdering, !propertyOrdering.isEmpty {
                try container.encode(propertyOrdering, forKey: .propertyOrdering)
            }

        case let .array(items, description):
            try container.encode("ARRAY", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            try container.encode(items, forKey: .items)

        case let .string(description, enumValues):
            try container.encode("STRING", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            if let enumValues, !enumValues.isEmpty {
                try container.encode(enumValues, forKey: .enum)
            }

        case let .number(description):
            try container.encode("NUMBER", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }

        case let .integer(description):
            try container.encode("INTEGER", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }

        case let .boolean(description):
            try container.encode("BOOLEAN", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
        }
    }

    private enum SchemaCodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case propertyOrdering
        case items
        case `enum`
    }
}
