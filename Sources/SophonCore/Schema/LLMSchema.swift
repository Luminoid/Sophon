//
//  LLMSchema.swift
//  SophonCore
//
//  Provider-neutral JSON schema for structured output. One value type, two
//  wire dialects: Gemini's OpenAPI-subset `responseSchema` (uppercase types,
//  `propertyOrdering`) and strict JSON Schema for OpenAI-compatible and
//  Anthropic structured outputs.
//

import Foundation

/// Wire dialect a schema is encoded in. Pick the one the target API expects;
/// the schema value itself is dialect-free.
public enum LLMSchemaDialect: Sendable, Equatable {
    /// Gemini `responseSchema` (OpenAPI 3.0 subset): uppercase type tokens,
    /// `required` exactly as declared, `propertyOrdering` honored.
    case openAPI
    /// Strict JSON Schema as required by OpenAI structured outputs and Anthropic
    /// `output_config`: lowercase types, `additionalProperties: false` on every
    /// object, every property listed in `required`, properties the schema did
    /// not declare required become nullable (`anyOf` with `null`), and
    /// `propertyOrdering` is dropped.
    case jsonSchema
}

/// JSON schema for structured output. When a request carries one, the provider
/// constrains the response to the declared structure.
public indirect enum LLMSchema: Encodable, Sendable {
    case object(properties: [String: Self], required: [String]? = nil, propertyOrdering: [String]? = nil, description: String? = nil)
    case array(items: Self, description: String? = nil)
    case string(description: String? = nil, enumValues: [String]? = nil)
    case number(description: String? = nil)
    case integer(description: String? = nil)
    case boolean(description: String? = nil)

    /// `JSONEncoder.userInfo` key selecting the dialect when a schema is encoded
    /// directly (value: an `LLMSchemaDialect`). Absent means `.openAPI`, the
    /// dialect Sophon 0.1 and 0.2 always produced, so consumers that encode a
    /// schema themselves keep byte-identical output.
    public static let dialectUserInfoKey: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "dev.luminoid.sophon.llmSchemaDialect") else {
            preconditionFailure("CodingUserInfoKey rejects only empty raw values")
        }
        return key
    }()

    /// The schema bound to an explicit dialect. Provider request DTOs embed
    /// this so their wire format never depends on encoder configuration.
    public func encoded(as dialect: LLMSchemaDialect) -> LLMSchemaDocument {
        LLMSchemaDocument(schema: self, dialect: dialect)
    }

    public func encode(to encoder: any Encoder) throws {
        let dialect = encoder.userInfo[Self.dialectUserInfoKey] as? LLMSchemaDialect ?? .openAPI
        try encode(to: encoder, dialect: dialect)
    }

    func encode(to encoder: any Encoder, dialect: LLMSchemaDialect) throws {
        switch dialect {
        case .openAPI:
            try encodeOpenAPI(to: encoder)
        case .jsonSchema:
            try encodeJSONSchema(to: encoder)
        }
    }

    // MARK: - OpenAPI (Gemini responseSchema)

    private func encodeOpenAPI(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: SchemaCodingKeys.self)

        switch self {
        case let .object(properties, required, propertyOrdering, description):
            try container.encode("OBJECT", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            try container.encode(properties.mapValues { $0.encoded(as: .openAPI) }, forKey: .properties)
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
            try container.encode(items.encoded(as: .openAPI), forKey: .items)

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

    // MARK: - Strict JSON Schema (OpenAI, Anthropic)

    private func encodeJSONSchema(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: SchemaCodingKeys.self)

        switch self {
        case let .object(properties, required, _, description):
            try container.encode("object", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            // Strict mode lists every property as required; the ones the caller
            // left optional become nullable so the model can still omit a value.
            let declaredRequired = Set(required ?? [])
            let wrapped = properties.reduce(into: [String: LLMSchemaDocument]()) { result, entry in
                result[entry.key] = LLMSchemaDocument(schema: entry.value, dialect: .jsonSchema, isNullable: !declaredRequired.contains(entry.key))
            }
            try container.encode(wrapped, forKey: .properties)
            try container.encode(properties.keys.sorted(), forKey: .required)
            try container.encode(false, forKey: .additionalProperties)

        case let .array(items, description):
            try container.encode("array", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            try container.encode(items.encoded(as: .jsonSchema), forKey: .items)

        case let .string(description, enumValues):
            try container.encode("string", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
            if let enumValues, !enumValues.isEmpty {
                try container.encode(enumValues, forKey: .enum)
            }

        case let .number(description):
            try container.encode("number", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }

        case let .integer(description):
            try container.encode("integer", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }

        case let .boolean(description):
            try container.encode("boolean", forKey: .type)
            if let description { try container.encode(description, forKey: .description) }
        }
    }

    private enum SchemaCodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case propertyOrdering
        case additionalProperties
        case items
        case `enum`
    }
}

/// A schema bound to a dialect. `Encodable`, so it can sit inside any request DTO
/// and always produces the same wire form regardless of the encoder's `userInfo`.
public struct LLMSchemaDocument: Encodable, Sendable {
    public let schema: LLMSchema
    public let dialect: LLMSchemaDialect
    /// Strict JSON Schema only: emit `anyOf: [schema, {type: null}]`.
    let isNullable: Bool

    public init(schema: LLMSchema, dialect: LLMSchemaDialect) {
        self.init(schema: schema, dialect: dialect, isNullable: false)
    }

    init(schema: LLMSchema, dialect: LLMSchemaDialect, isNullable: Bool) {
        self.schema = schema
        self.dialect = dialect
        self.isNullable = isNullable
    }

    public func encode(to encoder: any Encoder) throws {
        guard isNullable else {
            try schema.encode(to: encoder, dialect: dialect)
            return
        }
        var container = encoder.container(keyedBy: NullableCodingKeys.self)
        try container.encode([NullableAlternative.schema(Self(schema: schema, dialect: dialect)), .null], forKey: .anyOf)
    }

    private enum NullableCodingKeys: String, CodingKey {
        case anyOf
    }
}

/// One branch of a strict-dialect `anyOf: [schema, {"type": "null"}]`.
private enum NullableAlternative: Encodable {
    case schema(LLMSchemaDocument)
    case null

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .schema(document):
            try document.encode(to: encoder)
        case .null:
            var container = encoder.container(keyedBy: NullTypeCodingKeys.self)
            try container.encode("null", forKey: .type)
        }
    }
}

private enum NullTypeCodingKeys: String, CodingKey {
    case type
}
