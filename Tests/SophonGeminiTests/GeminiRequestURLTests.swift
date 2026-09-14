//
//  GeminiRequestURLTests.swift
//  SophonGeminiTests
//
//  Request URL hygiene: base-URL normalization with or without a trailing
//  slash, percent-encoding of a user-typed model ID, the 400 / 413 status
//  mapping, and the catalog's key hint.
//

import Foundation
import SophonGemini
import SophonTestSupport
import Testing

@MainActor
struct GeminiRequestURLTests {
    private func makeClient(apiBaseURL: String) -> GeminiAPIClient {
        GeminiAPIClient(configuration: TestSupport.makeConfiguration(apiBaseURL: apiBaseURL))
    }

    @Test
    func `A base URL without a trailing slash still builds the generateContent URL`() throws {
        let bare = try makeClient(apiBaseURL: "https://generativelanguage.googleapis.com/v1beta/models").buildRequest(promptText: "P", apiKey: "k")
        let slashed = try makeClient(apiBaseURL: "https://generativelanguage.googleapis.com/v1beta/models//").buildRequest(promptText: "P", apiKey: "k")
        let expected = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        #expect(bare.url?.absoluteString == expected)
        #expect(slashed.url?.absoluteString == expected)

        var configuration = TestSupport.makeConfiguration()
        configuration.apiBaseURL = "https://proxy.example.com/v1beta/models"
        #expect(configuration.apiBaseURL == "https://proxy.example.com/v1beta/models/")
    }

    @Test
    func `A model ID with reserved characters is encoded rather than becoming a query`() throws {
        let client = makeClient(apiBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/")
        let request = try client.buildRequest(promptText: "P", apiKey: "k", modelID: "gemini-x?key=leak#frag")
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasSuffix("/models/gemini-x%3Fkey=leak%23frag:generateContent"))
        #expect(request.url?.query == nil)
        #expect(request.url?.fragment == nil)
    }

    @Test
    func `400 and 413 map to invalidRequest and requestTooLarge`() {
        let client = makeClient(apiBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/")
        let badRequest = Data(#"{"error":{"code":400,"message":"Invalid JSON payload","status":"INVALID_ARGUMENT"}}"#.utf8)
        do {
            _ = try client.extractPlainTextResponse(data: badRequest, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400))
            Issue.record("Expected invalidRequest")
        } catch let GeminiError.invalidRequest(message) {
            #expect(message == "Invalid JSON payload")
        } catch {
            Issue.record("Unexpected \(error)")
        }

        do {
            _ = try client.extractPlainTextResponse(data: Data(), httpResponse: LLMTestSupport.makeHTTPResponse(status: 413))
            Issue.record("Expected requestTooLarge")
        } catch GeminiError.requestTooLarge {
            // expected
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test
    func `The catalog points at AI Studio for a key`() {
        #expect(GeminiModel.keyHintURL?.absoluteString == "https://aistudio.google.com/apikey")
    }
}
