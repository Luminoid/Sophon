//
//  GeminiModelList.swift
//  SophonGemini
//
//  Decodable model for the `GET /v1beta/models` listing, mapped onto the
//  provider-neutral `LLMRemoteModel`.
//

import Foundation
import SophonCore

struct GeminiModelListResponse: Decodable {
    let models: [Entry]?
    let nextPageToken: String?

    struct Entry: Decodable {
        /// Resource name, e.g. "models/gemini-3.8-flash".
        let name: String
        let displayName: String?
        let inputTokenLimit: Int?
        let outputTokenLimit: Int?
        let supportedGenerationMethods: [String]?

        /// Only models that answer `generateContent` are useful to Sophon's clients.
        var isGenerationModel: Bool {
            supportedGenerationMethods?.contains("generateContent") ?? false
        }

        var remoteModel: LLMRemoteModel {
            let id = name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name
            return LLMRemoteModel(id: id, displayName: displayName, inputTokenLimit: inputTokenLimit, outputTokenLimit: outputTokenLimit)
        }
    }
}
