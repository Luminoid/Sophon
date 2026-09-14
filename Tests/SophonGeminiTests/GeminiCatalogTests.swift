//
//  GeminiCatalogTests.swift
//  SophonGeminiTests
//
//  Locks the catalog metadata rules: the free-tier rule for the recommended
//  presets, the audit invariants, what `current` and its filters contain, and
//  the "Sophon decides" configuration defaults.
//

import Foundation
import SophonCore
import SophonGemini
import Testing

struct GeminiCatalogTests {
    @Test
    func `Catalog audit is clean`() {
        #expect(LLMCatalogAudit.violations(in: GeminiModel.self).isEmpty)
    }

    /// Users bring their own key, so the out-of-box models must work on a free
    /// key with no billing enabled.
    @Test
    func `Recommended default and fallback are current free-tier models`() {
        for preset in [GeminiModel.recommendedDefault, GeminiModel.recommendedFallback] {
            #expect(preset.hasFreeTier, "\(preset.modelID) must have a free tier")
            #expect(!preset.isDeprecated, "\(preset.modelID) must be current")
        }
        #expect(GeminiModel.recommendedDefault == .gemini38Flash)
        #expect(GeminiModel.recommendedFallback == .gemini35FlashLite)
        #expect(GeminiModel.freeAccess.isPermanent)
    }

    @Test
    func `current excludes deprecated presets and keeps paid ones`() {
        let current = GeminiModel.current
        #expect(!current.contains(.gemini3Flash))
        #expect(!current.contains(.gemini31FlashLite))
        #expect(current.contains(.gemini25Flash))
        #expect(current.contains(.gemini31Pro))
        #expect(current.contains(.gemini38Flash))
    }

    @Test
    func `Generation and tier filters match the documented rosters`() {
        #expect(GeminiModel.current(minimumGeneration: 3) == [.gemini31Pro, .gemini35FlashLite, .gemini35Flash, .gemini36Flash, .gemini37Flash, .gemini38Flash])
        #expect(!GeminiModel.currentFreeTier.contains(.gemini31Pro))
        #expect(GeminiModel.currentFreeTier.contains(.gemini38Flash))
    }

    @Test
    func `Deprecated presets carry their documented shutdown dates`() {
        #expect(GeminiModel.gemini31FlashLite.info.lifecycle == .deprecated(shutdown: LLMModelInfo.day(2027, 5, 7)))
        #expect(GeminiModel.gemini3Flash.info.lifecycle == .deprecated(shutdown: nil))
        #expect(GeminiModel.gemini38Flash.info.lifecycle == .current)
    }

    @Test
    func `A keychain-only configuration lets Sophon pick the models`() {
        let configuration = GeminiClientConfiguration(keychainAccount: "com.sophon.tests.catalog")
        #expect(configuration.defaultModel == .recommendedDefault)
        #expect(configuration.fallbackModel == .recommendedFallback)
        #expect(configuration.availableModels == GeminiModel.current)
    }

    @Test
    func `Custom models resolve their metadata from the ID`() {
        let custom = GeminiModel.custom("gemini-9-ultra")
        #expect(custom.customModelID == "gemini-9-ultra")
        #expect(custom.modelID == "gemini-9-ultra")
        #expect(custom.storageKey == "custom")
        #expect(!custom.isDeprecated)
    }
}
