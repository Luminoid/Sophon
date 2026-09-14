//
//  OpenAIResponseTests.swift
//  SophonOpenAITests
//
//  Response parsing and status mapping for both wire formats: text
//  extraction, refusal / filter / truncation surfacing, the model-not-found
//  gate that resets the stored selection, quota versus rate-limit on 429, and
//  the lenient error-body parser.
//

import Foundation
import SophonCore
import SophonOpenAI
import SophonTestSupport
import Testing

@MainActor
struct OpenAIResponseTests {
    private struct Result: Decodable {
        let name: String
    }

    private func makeGroq(defaults: UserDefaults = LLMTestSupport.makeDefaults()) -> GroqAPIClient {
        GroqAPIClient(configuration: GroqClientConfiguration(keychainAccount: "com.sophon.tests.groq", defaults: defaults, logHandler: { _, _ in }))
    }

    private func makeOpenAI() -> OpenAIAPIClient {
        OpenAIAPIClient(configuration: OpenAIClientConfiguration(keychainAccount: "com.sophon.tests.openAI", defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }))
    }

    private func chatBody(content: String, finishReason: String = "stop") -> Data {
        let escaped = content.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        return Data(#"{"choices":[{"message":{"role":"assistant","content":"\#(escaped)"},"finish_reason":"\#(finishReason)"}]}"#.utf8)
    }

    private func caught(_ block: () throws -> Void) -> OpenAIError? {
        do {
            try block()
        } catch let error as OpenAIError {
            return error
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        return nil
    }

    // MARK: - Chat Completions

    @Test
    func `Structured results decode from content, including markdown-wrapped JSON`() throws {
        let client = makeGroq()
        let plain = try client.decodeResponse(Result.self, data: chatBody(content: #"{"name": "Fern"}"#), httpResponse: LLMTestSupport.makeHTTPResponse(status: 200), label: "t")
        #expect(plain.name == "Fern")

        let fenced = try client.decodeResponse(Result.self, data: chatBody(content: "```json\n{\"name\": \"Moss\"}\n```"), httpResponse: LLMTestSupport.makeHTTPResponse(status: 200), label: "t")
        #expect(fenced.name == "Moss")

        let text = try client.extractPlainTextResponse(data: chatBody(content: "hello"), httpResponse: LLMTestSupport.makeHTTPResponse(status: 200))
        #expect(text == "hello")
    }

    @Test
    func `Array content parts are joined`() throws {
        let body = Data(#"{"choices":[{"message":{"content":[{"type":"text","text":"hel"},{"type":"text","text":"lo"}]},"finish_reason":"stop"}]}"#.utf8)
        let text = try makeGroq().extractPlainTextResponse(data: body, httpResponse: LLMTestSupport.makeHTTPResponse(status: 200))
        #expect(text == "hello")
    }

    @Test
    func `Refusals, filters, and length stops surface as errors`() {
        let client = makeGroq()
        let ok = LLMTestSupport.makeHTTPResponse(status: 200)

        let refusal = Data(#"{"choices":[{"message":{"content":null,"refusal":"I can't help with that"},"finish_reason":"stop"}]}"#.utf8)
        guard case .contentBlocked("refusal")? = caught({ _ = try client.extractPlainTextResponse(data: refusal, httpResponse: ok) }) else {
            Issue.record("Expected contentBlocked(refusal)")
            return
        }
        guard case .contentBlocked("content_filter")? = caught({ _ = try client.extractPlainTextResponse(data: chatBody(content: "x", finishReason: "content_filter"), httpResponse: ok) }) else {
            Issue.record("Expected contentBlocked(content_filter)")
            return
        }
        guard case .responseTruncated? = caught({ _ = try client.extractPlainTextResponse(data: chatBody(content: "partial", finishReason: "length"), httpResponse: ok) }) else {
            Issue.record("Expected responseTruncated")
            return
        }
    }

    // MARK: - Responses API

    @Test
    func `Responses API output_text and refusal items are recognized`() throws {
        let client = makeOpenAI()
        let ok = LLMTestSupport.makeHTTPResponse(status: 200)
        let body = Data(#"{"status":"completed","output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"{\"name\": \"Ivy\"}"}]}]}"#.utf8)
        #expect(try client.decodeResponse(Result.self, data: body, httpResponse: ok, label: "t").name == "Ivy")

        let refusal = Data(#"{"status":"completed","output":[{"type":"message","content":[{"type":"refusal","refusal":"no"}]}]}"#.utf8)
        guard case .contentBlocked? = caught({ _ = try client.extractPlainTextResponse(data: refusal, httpResponse: ok) }) else {
            Issue.record("Expected contentBlocked")
            return
        }

        let incomplete = Data(#"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[{"type":"message","content":[{"type":"output_text","text":"{\"na"}]}]}"#.utf8)
        guard case .responseTruncated? = caught({ _ = try client.extractPlainTextResponse(data: incomplete, httpResponse: ok) }) else {
            Issue.record("Expected responseTruncated")
            return
        }
    }

    // MARK: - Status mapping

    @Test
    func `Auth, quota, and rate-limit statuses map by code and body`() {
        let client = makeGroq()
        let empty = Data("{}".utf8)

        guard case .invalidAPIKey(provider: "Groq")? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 401)) }) else {
            Issue.record("Expected invalidAPIKey(Groq)")
            return
        }
        guard case .insufficientQuota? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 402)) }) else {
            Issue.record("Expected insufficientQuota on 402")
            return
        }
        let quota = Data(#"{"error":{"message":"You exceeded your current quota","type":"insufficient_quota","code":"insufficient_quota"}}"#.utf8)
        guard case .insufficientQuota? = caught({ _ = try client.extractPlainTextResponse(data: quota, httpResponse: LLMTestSupport.makeHTTPResponse(status: 429)) }) else {
            Issue.record("Expected insufficientQuota on 429 with billing code")
            return
        }
        guard case .rateLimited? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 429)) }) else {
            Issue.record("Expected rateLimited")
            return
        }
        guard case .serverError(500)? = caught({ _ = try client.extractPlainTextResponse(data: empty, httpResponse: LLMTestSupport.makeHTTPResponse(status: 500)) }) else {
            Issue.record("Expected serverError(500)")
            return
        }
    }

    @Test
    func `Only a body naming the model counts as a retired model`() {
        let defaults = LLMTestSupport.makeDefaults()
        defaults.set("llama3370BVersatile", forKey: "ai.groqModel")
        let client = makeGroq(defaults: defaults)

        let unknownModel = Data(#"{"error":{"message":"The model `llama-3.3-70b-versatile` does not exist or you do not have access to it.","type":"invalid_request_error","code":"model_not_found"}}"#
            .utf8)
        guard case .modelRetired("llama-3.3-70b-versatile")? = caught({ _ = try client.extractPlainTextResponse(data: unknownModel, httpResponse: LLMTestSupport.makeHTTPResponse(status: 404)) })
        else {
            Issue.record("Expected modelRetired")
            return
        }
        #expect(defaults.string(forKey: "ai.groqModel") == GroqModel.recommendedFallback.storageKey)

        defaults.set("llama3370BVersatile", forKey: "ai.groqModel")
        let wrongPath = Data(#"{"error":{"message":"Not found","type":"invalid_request_error","code":null}}"#.utf8)
        guard case .serverError(404)? = caught({ _ = try client.extractPlainTextResponse(data: wrongPath, httpResponse: LLMTestSupport.makeHTTPResponse(status: 404)) }) else {
            Issue.record("Expected serverError(404) for a plain 404")
            return
        }
        #expect(defaults.string(forKey: "ai.groqModel") == "llama3370BVersatile", "a plain 404 must not reset the selection")

        let deepSeekStyle = Data(#"{"error":{"message":"Model Not Exist","type":"invalid_request_error","param":null,"code":"invalid_request_error"}}"#.utf8)
        guard case .modelRetired? = caught({ _ = try client.extractPlainTextResponse(data: deepSeekStyle, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected modelRetired on a 400 that names the model")
            return
        }

        let badRequest = Data(#"{"error":{"message":"temperature must be between 0 and 2","type":"invalid_request_error"}}"#.utf8)
        guard case .invalidRequest? = caught({ _ = try client.extractPlainTextResponse(data: badRequest, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected invalidRequest")
            return
        }
    }

    @Test
    func `Flat and numeric error bodies still parse`() {
        let client = makeGroq()
        let mistralStyle = Data(#"{"object":"error","message":"Invalid model: nope","type":"invalid_model","code":"1500"}"#.utf8)
        guard case .modelRetired? = caught({ _ = try client.extractPlainTextResponse(data: mistralStyle, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected modelRetired from a flat body")
            return
        }
        let zhipuStyle = Data(#"{"error":{"code":1211,"message":"模型不存在，请检查模型代码。"}}"#.utf8)
        guard case .modelRetired? = caught({ _ = try client.extractPlainTextResponse(data: zhipuStyle, httpResponse: LLMTestSupport.makeHTTPResponse(status: 400)) }) else {
            Issue.record("Expected modelRetired from a numeric code")
            return
        }
    }
}
