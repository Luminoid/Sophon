//
//  AnthropicResponseTests.swift
//  SophonAnthropicTests
//
//  Response parsing and status mapping for the Messages API: text joining,
//  refusal and max_tokens stops, the model-naming 404 gate, 413 / 429 / 529
//  classification, and the string-catalog lock.
//

import Foundation
import SophonAnthropic
import SophonCore
import SophonTestSupport
import Testing

@MainActor
struct AnthropicResponseTests {
    private struct Result: Decodable {
        let name: String
    }

    private func makeClient(defaults: UserDefaults = LLMTestSupport.makeDefaults()) -> AnthropicAPIClient {
        AnthropicAPIClient(configuration: AnthropicClientConfiguration(keychainAccount: "com.sophon.tests.anthropic", defaults: defaults, logHandler: { _, _ in }))
    }

    private func messageBody(text: String, stopReason: String = "end_turn") -> Data {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        return Data(#"{"type":"message","content":[{"type":"text","text":"\#(escaped)"}],"stop_reason":"\#(stopReason)"}"#.utf8)
    }

    private func caught(_ block: () throws -> Void) -> AnthropicError? {
        do {
            try block()
        } catch let error as AnthropicError {
            return error
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        return nil
    }

    @Test
    func `Text blocks are joined and thinking blocks skipped`() throws {
        let client = makeClient()
        let body = Data(#"{"content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"name\": "},{"type":"text","text":"\"Fern\"}"}],"stop_reason":"end_turn"}"#.utf8)
        let result = try client.decodeResponse(Result.self, data: body, httpResponse: LLMTestSupport.makeHTTPResponse(status: 200), label: "t")
        #expect(result.name == "Fern")
        #expect(try client.extractPlainTextResponse(data: messageBody(text: "hello"), httpResponse: LLMTestSupport.makeHTTPResponse(status: 200)) == "hello")
    }

    @Test
    func `Refusal and max_tokens stops surface as errors`() {
        let client = makeClient()
        let ok = LLMTestSupport.makeHTTPResponse(status: 200)
        guard case .contentBlocked("refusal")? = caught({ _ = try client.extractPlainTextResponse(data: messageBody(text: "", stopReason: "refusal"), httpResponse: ok) }) else {
            Issue.record("Expected contentBlocked(refusal)")
            return
        }
        guard case .responseTruncated? = caught({ _ = try client.extractPlainTextResponse(data: messageBody(text: "partial", stopReason: "max_tokens"), httpResponse: ok) }) else {
            Issue.record("Expected responseTruncated")
            return
        }
        guard case .invalidResponse? = caught({ _ = try client.extractPlainTextResponse(data: Data(#"{"content":[],"stop_reason":"end_turn"}"#.utf8), httpResponse: ok) }) else {
            Issue.record("Expected invalidResponse on empty content")
            return
        }
    }

    @Test
    func `Statuses map to the Claude error cases`() {
        let client = makeClient()
        let empty = Data("{}".utf8)
        guard case .invalidAPIKey? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 401)) }) else {
            Issue.record("Expected invalidAPIKey")
            return
        }
        guard case .requestTooLarge? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 413)) }) else {
            Issue.record("Expected requestTooLarge")
            return
        }
        guard case .rateLimited? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 429)) }) else {
            Issue.record("Expected rateLimited")
            return
        }
        guard case .overloaded? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 529)) }) else {
            Issue.record("Expected overloaded")
            return
        }
        let bad = Data(#"{"type":"error","error":{"type":"invalid_request_error","message":"temperature is not supported"}}"#.utf8)
        guard case .invalidRequest? = caught({ _ = try client.extractPlainTextResponse(data: bad, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected invalidRequest")
            return
        }
        #expect(AnthropicError.overloaded.isRetryable)
        #expect(AnthropicError.requestTooLarge.isRetryable)
        #expect(AnthropicError.requestTooLarge.shouldCompressImagesOnRetry)
        #expect(!AnthropicError.invalidRequest("x").isRetryable)
    }

    @Test
    func `Only a 404 naming the model resets the selection`() {
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("claudeOpus5", forKey: "ai.anthropicModel")
        let client = makeClient(defaults: defaults)

        let unknownModel = Data(#"{"type":"error","error":{"type":"not_found_error","message":"model: claude-opus-5"}}"#.utf8)
        guard case .modelRetired("claude-opus-5")? = caught({ _ = try client.extractPlainTextResponse(data: unknownModel, httpResponse: LLMTestSupport.makeHTTPResponse(status: 404)) }) else {
            Issue.record("Expected modelRetired")
            return
        }
        #expect(defaults.string(forKey: "ai.anthropicModel") == "claudeHaiku45")

        defaults.set("claudeOpus5", forKey: "ai.anthropicModel")
        let wrongPath = Data(#"{"type":"error","error":{"type":"not_found_error","message":"Not Found"}}"#.utf8)
        guard case .serverError(404)? = caught({ _ = try client.extractPlainTextResponse(data: wrongPath, httpResponse: LLMTestSupport.makeHTTPResponse(status: 404)) }) else {
            Issue.record("Expected serverError(404)")
            return
        }
        #expect(defaults.string(forKey: "ai.anthropicModel") == "claudeOpus5")
    }

    @Test
    func `An exhausted credit balance is insufficientQuota, other 400s stay invalidRequest`() {
        let client = makeClient()
        let broke = Data(#"{"type":"error","error":{"type":"invalid_request_error","message":"Your credit balance is too low to access the Anthropic API."}}"#.utf8)
        guard case .insufficientQuota? = caught({ _ = try client.extractPlainTextResponse(data: broke, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected insufficientQuota")
            return
        }
        #expect(!AnthropicError.insufficientQuota.isRetryable)

        // A 400 that mentions the model is a request problem, never a retired model.
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("claudeOpus5", forKey: "ai.anthropicModel")
        let modelMention = Data(#"{"type":"error","error":{"type":"invalid_request_error","message":"temperature is not supported by this model"}}"#.utf8)
        guard case .invalidRequest? = caught({ _ = try makeClient(defaults: defaults).extractPlainTextResponse(data: modelMention, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected invalidRequest")
            return
        }
        #expect(defaults.string(forKey: "ai.anthropicModel") == "claudeOpus5")
    }

    @Test
    func `errorDescription resolves from the package strings`() throws {
        let cases: [AnthropicError] = [
            .apiKeyMissing, .apiKeyInaccessible(-25308), .invalidAPIKey, .invalidEndpoint("x"), .invalidRequest("y"), .emptyInput, .imageEncodingFailed,
            .requestFailed(URLError(.timedOut)), .invalidResponse, .rateLimited, .insufficientQuota, .overloaded, .requestTooLarge,
            .serverError(500), .modelRetired("m"), .contentBlocked("refusal"), .responseTruncated,
        ]
        for error in cases {
            let description = try #require(error.errorDescription)
            #expect(!description.isEmpty)
            #expect(!description.hasPrefix("anthropic.error."))
            #expect(!description.hasPrefix("llm.error."))
        }
        #expect(AnthropicError.requestTooLarge.retriesOnlyWithSmallerImages)
        #expect(!AnthropicError.overloaded.retriesOnlyWithSmallerImages)
    }
}
