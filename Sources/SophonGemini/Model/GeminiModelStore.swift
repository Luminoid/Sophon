//
//  GeminiModelStore.swift
//  SophonGemini
//
//  Persistence and per-app resolution for the model selection: the shared
//  `LLMModelStore` specialized for the Gemini catalog (the `GeminiModelStore`
//  alias in `GeminiCompatibility.swift`), built from a
//  `GeminiClientConfiguration`.
//

import Foundation
import SophonCore

public extension LLMModelStore where Model == GeminiModel {
    init(configuration: GeminiClientConfiguration) {
        self.init(
            defaults: configuration.defaults,
            modelDefaultsKey: configuration.modelDefaultsKey,
            customModelDefaultsKey: configuration.customModelDefaultsKey,
            defaultModel: configuration.defaultModel,
            fallbackModel: configuration.fallbackModel,
            availableModels: configuration.availableModels
        )
    }
}
