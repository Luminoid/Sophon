//
//  LLMMessageTests.swift
//  SophonCoreTests
//
//  Locks the neutral message types: role parsing from provider names, part
//  accessors, and the direct JSON encoding consumers relied on since 0.1.
//

import Foundation
import SophonCore
import Testing

struct LLMMessageTests {
    @Test
    func `Provider role names map onto the neutral set`() {
        #expect(LLMRole(providerRole: "user") == .user)
        #expect(LLMRole(providerRole: "model") == .assistant)
        #expect(LLMRole(providerRole: "Assistant") == .assistant)
        #expect(LLMRole(providerRole: "system") == .system)
        #expect(LLMRole(providerRole: "tool") == nil)
        #expect(LLMMessage(parts: [], role: "model").role == .assistant)
        #expect(LLMMessage(parts: [], role: "nope").role == nil)
        #expect(LLMMessage(parts: []).role == nil)
    }

    @Test
    func `Part accessors distinguish text from media`() {
        let text = LLMPart.text("hi")
        let media = LLMPart.inlineData(mimeType: "image/png", data: "QUJD")
        #expect(!text.isMedia)
        #expect(text.text == "hi")
        #expect(text.mimeType == nil)
        #expect(media.isMedia)
        #expect(media.mimeType == "image/png")
        #expect(media.text == nil)
    }

    @Test
    func `Parts and messages encode in the historical JSON shape`() throws {
        let part = try encodeToDictionary(LLMPart.inlineData(mimeType: "application/pdf", data: "QUJD"))
        let inline = try #require(part["inlineData"] as? [String: Any])
        #expect(inline["mimeType"] as? String == "application/pdf")
        #expect(inline["data"] as? String == "QUJD")

        let text = try encodeToDictionary(LLMPart.text("hello"))
        #expect(text["text"] as? String == "hello")

        let message = try encodeToDictionary(LLMMessage(parts: [.text("hello")], role: .assistant))
        #expect(message["role"] as? String == "assistant")
        #expect((message["parts"] as? [[String: Any]])?.count == 1)

        let anonymous = try encodeToDictionary(LLMMessage(parts: [.text("hello")]))
        #expect(anonymous["role"] == nil)
    }

    private func encodeToDictionary(_ value: some Encodable) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        return try #require(object as? [String: Any])
    }
}
