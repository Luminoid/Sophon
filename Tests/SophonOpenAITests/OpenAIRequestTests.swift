//
//  OpenAIRequestTests.swift
//  SophonOpenAITests
//
//  Request building for both wire formats and both structured-output modes:
//  headers (key never in the URL), body shape, media-before-text ordering,
//  temperature gating by model, system-message hoisting, and attribution
//  headers.
//

import Foundation
import SophonCore
import SophonOpenAI
import SophonTestSupport
import Testing

@MainActor
struct OpenAIRequestTests {
    private let schema = LLMSchema.object(properties: ["name": .string(), "score": .number()], required: ["name"])

    private func makeGroq(appName: String? = nil, appURL: URL? = nil) -> GroqAPIClient {
        GroqAPIClient(configuration: GroqClientConfiguration(
            keychainAccount: "com.sophon.tests.groq", defaults: LLMTestSupport.makeDefaults(), appName: appName, appURL: appURL, logHandler: { _, _ in }
        ))
    }

    private func makeOpenAI() -> OpenAIAPIClient {
        OpenAIAPIClient(configuration: OpenAIClientConfiguration(keychainAccount: "com.sophon.tests.openAI", defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }))
    }

    private func makeDeepSeek() -> DeepSeekAPIClient {
        DeepSeekAPIClient(configuration: DeepSeekClientConfiguration(keychainAccount: "com.sophon.tests.deepSeek", defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }))
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try #require(LLMTestSupport.jsonObject(request.httpBody))
    }

    // MARK: - Chat Completions

    @Test
    func `Chat Completions body carries model, typed parts, strict schema, and max_tokens`() throws {
        let request = try makeGroq().buildRequest(
            parts: [.inlineData(mimeType: "application/pdf", data: "QUJD")],
            promptText: "Read the document",
            apiKey: "k",
            responseSchema: schema
        )

        #expect(request.url?.absoluteString == "https://api.groq.com/openai/v1/chat/completions")
        let json = try body(request)
        #expect(json["model"] as? String == "openai/gpt-oss-120b")
        #expect(json["max_tokens"] as? Int == 16000)
        #expect(json["max_completion_tokens"] == nil)
        #expect(json["temperature"] as? Double == 0.1)

        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] as? String == "user")
        let content = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "file")
        #expect((content.first?["file"] as? [String: Any])?["file_data"] as? String == "data:application/pdf;base64,QUJD")
        #expect(content.last?["type"] as? String == "text")
        #expect(content.last?["text"] as? String == "Read the document")

        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let envelope = try #require(format["json_schema"] as? [String: Any])
        #expect(envelope["strict"] as? Bool == true)
        let encoded = try #require(envelope["schema"] as? [String: Any])
        #expect(encoded["type"] as? String == "object")
        #expect(encoded["additionalProperties"] as? Bool == false)
    }

    @Test
    func `Text-only messages encode content as a plain string and images as data URLs`() throws {
        let contents = [
            LLMMessage(parts: [.text("system rules")], role: .system),
            LLMMessage(parts: [.inlineData(mimeType: "image/jpeg", data: "QUJD"), .text("what is this?")], role: .user),
            LLMMessage(parts: [.text("a plant")], role: "model"),
        ]
        let request = try makeGroq().buildMultiTurnRequest(contents: contents, apiKey: "k")
        let json = try body(request)
        let messages = try #require(json["messages"] as? [[String: Any]])

        #expect(messages.map { $0["role"] as? String } == ["system", "user", "assistant"])
        #expect(messages[0]["content"] as? String == "system rules")
        let userContent = try #require(messages[1]["content"] as? [[String: Any]])
        #expect(userContent.first?["type"] as? String == "image_url")
        #expect((userContent.first?["image_url"] as? [String: Any])?["url"] as? String == "data:image/jpeg;base64,QUJD")
        #expect(messages[2]["content"] as? String == "a plant")
        #expect(json["response_format"] == nil)
    }

    @Test
    func `json_object mode spells the schema out in the prompt`() throws {
        let request = try makeDeepSeek().buildRequest(promptText: "Extract", apiKey: "k", responseSchema: schema)
        let json = try body(request)

        #expect((json["response_format"] as? [String: Any])?["type"] as? String == "json_object")
        let messages = try #require(json["messages"] as? [[String: Any]])
        let text = try #require(messages[0]["content"] as? String)
        #expect(text.hasPrefix("Extract"))
        #expect(text.contains("JSON schema"))
        #expect(text.contains("\"additionalProperties\""))
    }

    // MARK: - Responses API

    @Test
    func `Responses body carries input parts, instructions, text format, and max_output_tokens`() throws {
        let contents = [
            LLMMessage(parts: [.text("be brief")], role: .system),
            LLMMessage(parts: [.inlineData(mimeType: "image/png", data: "QUJD"), .text("describe")], role: .user),
        ]
        let request = try makeOpenAI().buildMultiTurnRequest(contents: contents, apiKey: "k", responseSchema: schema)

        #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
        let json = try body(request)
        #expect(json["model"] as? String == "gpt-5.6-luna")
        #expect(json["instructions"] as? String == "be brief")
        #expect(json["max_output_tokens"] as? Int == 16000)
        #expect(json["temperature"] == nil, "reasoning models reject sampling parameters")
        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input.count == 1)
        let content = try #require(input[0]["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "input_image")
        #expect(content.first?["image_url"] as? String == "data:image/png;base64,QUJD")
        #expect(content.last?["type"] as? String == "input_text")
        let format = try #require((json["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect(format["strict"] as? Bool == true)
        #expect((format["schema"] as? [String: Any])?["type"] as? String == "object")
    }

    @Test
    func `Temperature is sent only for models that accept it`() throws {
        let client = makeOpenAI()
        let reasoning = try body(client.buildRequest(promptText: "P", apiKey: "k", modelID: "gpt-5.6-terra", temperature: 0.5))
        #expect(reasoning["temperature"] == nil)

        let classic = try body(client.buildRequest(promptText: "P", apiKey: "k", modelID: "gpt-4.1", temperature: 0.5))
        #expect(classic["temperature"] as? Double == 0.5)

        let unknown = try body(client.buildRequest(promptText: "P", apiKey: "k", modelID: "gpt-9-nova", temperature: 0.5))
        #expect(unknown["temperature"] == nil, "custom IDs skip sampling parameters")
    }

    // MARK: - Headers

    @Test
    func `The API key rides in the Authorization header, never the URL`() throws {
        let single = try makeGroq().buildRequest(promptText: "P", apiKey: "SECRET")
        let multi = try makeOpenAI().buildMultiTurnRequest(contents: [], apiKey: "SECRET")
        for request in [single, multi] {
            let url = try #require(request.url)
            #expect(url.query() == nil)
            #expect(!url.absoluteString.contains("SECRET"))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer SECRET")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        }
    }

    @Test
    func `Attribution headers are sent only when configured`() throws {
        let plain = try makeGroq().buildRequest(promptText: "P", apiKey: "k")
        #expect(plain.value(forHTTPHeaderField: "X-Title") == nil)
        #expect(plain.value(forHTTPHeaderField: "HTTP-Referer") == nil)

        let attributed = try makeGroq(appName: "Sophon Example", appURL: URL(string: "https://luminoid.dev")).buildRequest(promptText: "P", apiKey: "k")
        #expect(attributed.value(forHTTPHeaderField: "X-Title") == "Sophon Example")
        #expect(attributed.value(forHTTPHeaderField: "HTTP-Referer") == "https://luminoid.dev")
    }

    @Test
    func `Regional endpoints resolve their generation URL`() throws {
        let client = GLMAPIClient(configuration: GLMClientConfiguration(
            keychainAccount: "com.sophon.tests.glm", endpoint: GLMModel.endpoint(region: .china), defaults: LLMTestSupport.makeDefaults(), logHandler: { _, _ in }
        ))
        let request = try client.buildRequest(promptText: "P", apiKey: "k")
        #expect(request.url?.absoluteString == "https://open.bigmodel.cn/api/paas/v4/chat/completions")
        #expect(client.providerDisplayName == "GLM")
        #expect(client.currentModelID == "glm-4.7-flash")
    }
}
