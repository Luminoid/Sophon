//
//  GeminiAvailability.swift
//  SophonGemini
//
//  Availability gate and API-key surface. The helpers (`hasAPIKey`,
//  `isEnabled`, `saveAPIKey`, `maskedAPIKeyDisplay`, ...) come from
//  `LLMProviderConfiguration`; only the Gemini-named alias lives here.
//

import Foundation
import SophonCore

extension GeminiClientConfiguration: LLMProviderConfiguration {}

public extension GeminiClientConfiguration {
    /// Central availability check: the settings toggle is on AND an API key is stored.
    var isGeminiAvailable: Bool {
        isAvailable
    }
}
