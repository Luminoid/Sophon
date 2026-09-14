//
//  GeminiSourceCompatibilityTests.swift
//  SophonGeminiTests
//
//  Compile-time guard for the consumer apps: every Gemini-era spelling they
//  use (typealiased types, inline implicit members, string roles, the README
//  snippets) must keep compiling unchanged now that the types live in
//  SophonCore.
//

import Foundation
import SophonGemini
import Testing

@MainActor
struct GeminiSourceCompatibilityTests {
    private struct Extraction: Decodable {
        let title: String
    }

    @Test
    func `Gemini-era type names and inline members still compile`() throws {
        let schema: GeminiSchema = .object(
            properties: ["title": .string(), "days": .array(items: .integer())],
            required: ["title"],
            propertyOrdering: ["title", "days"]
        )
        let parts: [GeminiPart] = [.inlineData(mimeType: "image/jpeg", data: "QUJD"), .text("prompt")]
        let contents: [GeminiContent] = [
            GeminiContent(parts: parts, role: "user"),
            GeminiContent(parts: [.text("reply")], role: "model"),
            GeminiContent(parts: [.text("no role")]),
        ]
        let policy: GeminiRetryPolicy = .default
        let variant = GeminiRequestVariant(useCompressedImages: false, modelID: GeminiModel.gemini38Flash.modelID)

        #expect(contents[0].role == .user)
        #expect(contents[1].role == .assistant)
        #expect(contents[2].role == nil)
        #expect(policy.maxAttempts == 3)
        #expect(variant.modelID == "gemini-3.8-flash")

        let client = GeminiAPIClient(configuration: TestSupport.makeConfiguration())
        let single = try client.buildRequest(parts: parts, promptText: "P", apiKey: "k", modelID: variant.modelID, responseSchema: schema)
        let multi = try client.buildMultiTurnRequest(contents: contents, apiKey: "k", modelID: variant.modelID)
        #expect(single.httpBody != nil)
        #expect(multi.httpBody != nil)
    }

    @Test
    func `Model pattern matching and store access keep their shape`() {
        let model: GeminiModel = .custom("x")
        var isCustom = false
        if case .custom = model { isCustom = true }
        #expect(isCustom)
        #expect(GeminiModel.from(storageKey: "gemini38Flash") == .gemini38Flash)
        #expect(GeminiModel.allStandardCases.contains(.gemini31Pro))

        let client = GeminiAPIClient(configuration: TestSupport.makeConfiguration())
        let store: GeminiModelStore = client.modelStore
        store.select(.gemini37Flash)
        #expect(store.current == .gemini37Flash)
        #expect(client.currentModelID == "gemini-3.7-flash")
        #expect(client.providerDisplayName == "Gemini")
    }

    @Test
    func `Configuration helpers resolve through the shared protocol`() {
        let configuration = TestSupport.makeConfiguration()
        #expect(configuration.isEnabled == false)
        configuration.setEnabled(true)
        #expect(configuration.isEnabled)
        #expect(configuration.isGeminiAvailable == configuration.hasAPIKey)
        #expect(GeminiError.apiKeyMissing.isRetryable == false)
        #expect(GeminiError.emptyInput.errorDescription != nil)
    }
}
