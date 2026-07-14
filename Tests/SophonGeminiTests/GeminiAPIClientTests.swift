//
//  GeminiAPIClientTests.swift
//  SophonGeminiTests
//
//  Unit tests for GeminiAPIClient response parsing, error mapping, and request
//  building (schema, part ordering, header-only API key).
//

import Foundation
import SophonGemini
import Testing

@MainActor
struct GeminiAPIClientTests {
    private let client = GeminiAPIClient(configuration: TestSupport.makeConfiguration())

    private struct TestResult: Decodable {
        let name: String
        let confidence: Double?
    }

    // MARK: - decodeResponse: Success

    @Test
    func `decodeResponse parses valid result from 200 response`() throws {
        let jsonText = #"{"name": "Snake Plant", "confidence": 0.9}"#
        let (data, httpResponse) = makeHTTPBody(body: wrapInGeminiResponse(jsonText), statusCode: 200)

        let result = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        #expect(result.name == "Snake Plant")
        #expect(result.confidence == 0.9)
    }

    @Test
    func `decodeResponse handles markdown-wrapped JSON`() throws {
        let jsonText = "```json\n{\"name\": \"Fern\", \"confidence\": 0.8}\n```"
        let (data, httpResponse) = makeHTTPBody(body: wrapInGeminiResponse(jsonText), statusCode: 200)

        let result = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        #expect(result.name == "Fern")
    }

    @Test
    func `decodeResponse handles JSON with extra text before braces`() throws {
        let jsonText = "Here is the result: {\"name\": \"Cactus\", \"confidence\": 0.7}"
        let (data, httpResponse) = makeHTTPBody(body: wrapInGeminiResponse(jsonText), statusCode: 200)

        let result = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        #expect(result.name == "Cactus")
    }

    // MARK: - decodeResponse: HTTP Errors

    @Test(arguments: [401, 403])
    func `decodeResponse throws invalidAPIKey on auth errors`(status: Int) {
        let (data, httpResponse) = makeHTTPBody(body: "{}", statusCode: status)

        var caught: GeminiError?
        do {
            _ = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        } catch let error as GeminiError {
            caught = error
        } catch {}

        guard let caught, case .invalidAPIKey = caught else {
            Issue.record("Expected invalidAPIKey, got \(String(describing: caught))")
            return
        }
    }

    @Test
    func `decodeResponse throws rateLimited on 429`() {
        let (data, httpResponse) = makeHTTPBody(body: "{}", statusCode: 429)

        var caught: GeminiError?
        do {
            _ = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        } catch let error as GeminiError {
            caught = error
        } catch {}

        guard let caught, case .rateLimited = caught else {
            Issue.record("Expected rateLimited, got \(String(describing: caught))")
            return
        }
    }

    @Test
    func `decodeResponse throws serverError on 500`() {
        let (data, httpResponse) = makeHTTPBody(body: "{}", statusCode: 500)

        var caught: GeminiError?
        do {
            _ = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        } catch let error as GeminiError {
            caught = error
        } catch {}

        guard let caught, case let .serverError(code) = caught, code == 500 else {
            Issue.record("Expected serverError(500), got \(String(describing: caught))")
            return
        }
    }

    // MARK: - decodeResponse: API Error in Body

    @Test
    func `decodeResponse throws on Gemini API error in response body`() {
        let body = #"{"error": {"message": "Invalid key", "code": 403}}"#
        let (data, httpResponse) = makeHTTPBody(body: body, statusCode: 200)

        #expect(throws: GeminiError.self) {
            try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        }
    }

    // MARK: - decodeResponse: Invalid Response

    @Test
    func `decodeResponse throws invalidResponse on empty text`() {
        let body = #"{"candidates": [{"content": {"parts": [{"text": ""}]}}]}"#
        let (data, httpResponse) = makeHTTPBody(body: body, statusCode: 200)

        #expect(throws: GeminiError.self) {
            try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        }
    }

    @Test
    func `decodeResponse throws invalidResponse on no candidates`() {
        let body = #"{"candidates": []}"#
        let (data, httpResponse) = makeHTTPBody(body: body, statusCode: 200)

        #expect(throws: GeminiError.self) {
            try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        }
    }

    @Test
    func `decodeResponse recovers truncated JSON via brace repair`() throws {
        let truncatedInner = #"{"name": "Snake Plant", "confidence": 0.9"# // missing closing brace
        let (data, httpResponse) = makeHTTPBody(body: wrapInGeminiResponse(truncatedInner), statusCode: 200)

        let result = try client.decodeResponse(TestResult.self, data: data, httpResponse: httpResponse, label: "test")
        #expect(result.name == "Snake Plant")
    }

    // MARK: - buildRequest

    @Test
    func `buildRequest includes responseSchema in body when provided`() throws {
        let schema = GeminiSchema.object(properties: ["name": .string()], required: ["name"])
        let request = try client.buildRequest(promptText: "Identify this plant", apiKey: "test-key", responseSchema: schema)

        let config = try generationConfig(of: request)
        #expect(config["response_schema"] != nil)
    }

    @Test
    func `buildRequest omits responseSchema when nil`() throws {
        let request = try client.buildRequest(promptText: "Identify this plant", apiKey: "test-key")

        let config = try generationConfig(of: request)
        #expect(config["response_schema"] == nil)
    }

    @Test
    func `buildRequest encodes JSON mime type and temperature defaults`() throws {
        let request = try client.buildRequest(promptText: "P", apiKey: "k")

        let config = try generationConfig(of: request)
        #expect(config["response_mime_type"] as? String == "application/json")
        #expect(config["temperature"] as? Double == 0.1)
    }

    @Test
    func `buildRequest honors a temperature override`() throws {
        let request = try client.buildRequest(promptText: "P", apiKey: "k", temperature: 0.5)

        let config = try generationConfig(of: request)
        #expect(config["temperature"] as? Double == 0.5)
    }

    @Test
    func `buildRequest places media parts before the prompt text`() throws {
        // The model reads the prompt in the context of the already-ingested
        // documents, so attachment parts must precede the text part.
        let request = try client.buildRequest(
            parts: [.inlineData(mimeType: "application/pdf", data: "QUJD")],
            promptText: "Read the document",
            apiKey: "k"
        )

        let parts = try requestParts(of: request)
        #expect(parts.count == 2)
        #expect(parts.first?["inlineData"] != nil)
        #expect((parts.last?["text"] as? String) == "Read the document")
    }

    @Test
    func `buildMultiTurnRequest defaults to plain text mime type`() throws {
        let request = try client.buildMultiTurnRequest(contents: [], apiKey: "k")

        let config = try generationConfig(of: request)
        #expect(config["response_mime_type"] as? String == "text/plain")
        #expect(config["temperature"] as? Double == 0.3)
    }

    @Test
    func `buildRequest keeps the API key out of the URL`() throws {
        // NSURLError userInfo embeds the failing URL, so a query-string key
        // would leak into transport-error logs. The key must ride in the
        // x-goog-api-key header instead, on both request builders.
        let single = try client.buildRequest(promptText: "P", apiKey: "SECRET")
        let multi = try client.buildMultiTurnRequest(contents: [], apiKey: "SECRET")
        for request in [single, multi] {
            let url = try #require(request.url)
            #expect(url.query() == nil)
            #expect(!url.absoluteString.contains("SECRET"))
            #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "SECRET")
        }
    }

    // MARK: - Helpers

    private func wrapInGeminiResponse(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return #"{"candidates": [{"content": {"parts": [{"text": "\#(escaped)"}]}}]}"#
    }

    private func makeHTTPBody(body: String, statusCode: Int) -> (Data, HTTPURLResponse) {
        (Data(body.utf8), TestSupport.makeHTTPResponse(status: statusCode))
    }

    private func bodyJSON(of request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        return try #require(json)
    }

    private func generationConfig(of request: URLRequest) throws -> [String: Any] {
        try #require(bodyJSON(of: request)["generationConfig"] as? [String: Any])
    }

    private func requestParts(of request: URLRequest) throws -> [[String: Any]] {
        let contents = try #require(bodyJSON(of: request)["contents"] as? [[String: Any]])
        return try #require(contents.first?["parts"] as? [[String: Any]])
    }
}
