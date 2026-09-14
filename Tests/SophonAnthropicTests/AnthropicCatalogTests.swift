//
//  AnthropicCatalogTests.swift
//  SophonAnthropicTests
//
//  Locks the Claude catalog: audit invariants, the Sonnet-over-Opus
//  recommendation, sampling-parameter flags, and configuration defaults.
//

import Foundation
import SophonAnthropic
import SophonCore
import Testing

struct AnthropicCatalogTests {
    @Test
    func `Catalog audit is clean and every preset is current`() {
        #expect(LLMCatalogAudit.violations(in: AnthropicModel.self).isEmpty)
        #expect(AnthropicModel.current == AnthropicModel.allStandardCases)
        #expect(AnthropicModel.currentFreeTier.isEmpty)
        if case .trialCredit = AnthropicModel.freeAccess {} else { Issue.record("Anthropic access is a trial credit") }
    }

    @Test
    func `Recommended presets and IDs`() {
        #expect(AnthropicModel.recommendedDefault == .claudeSonnet5)
        #expect(AnthropicModel.recommendedFallback == .claudeHaiku45)
        #expect(AnthropicModel.claudeSonnet5.modelID == "claude-sonnet-5")
        #expect(AnthropicModel.claudeHaiku45.modelID == "claude-haiku-4-5")
        #expect(AnthropicModel.claudeFable51.modelID == "claude-fable-5-1")
        #expect(AnthropicModel.from(storageKey: "claudeOpus5") == .claudeOpus5)
    }

    @Test
    func `Sampling parameters are flagged per model line`() {
        for preset in [AnthropicModel.claudeOpus5, .claudeSonnet5, .claudeFable51, .claudeFable5, .claudeOpus48, .claudeOpus47] {
            #expect(!preset.info.supportsTemperature, "\(preset.modelID) rejects sampling parameters")
        }
        for preset in [AnthropicModel.claudeHaiku45, .claudeOpus46, .claudeSonnet46, .claudeOpus45, .claudeSonnet45] {
            #expect(preset.info.supportsTemperature, "\(preset.modelID) accepts sampling parameters")
        }
        #expect(AnthropicModel.current(minimumGeneration: 5) == [.claudeOpus5, .claudeSonnet5, .claudeFable51, .claudeFable5])
    }

    @Test
    func `A keychain-only configuration lets Sophon pick the models`() {
        let configuration = AnthropicClientConfiguration(keychainAccount: "com.sophon.tests.anthropic")
        #expect(configuration.defaultModel == .claudeSonnet5)
        #expect(configuration.fallbackModel == .claudeHaiku45)
        #expect(configuration.availableModels == AnthropicModel.current)
        #expect(configuration.enabledDefaultsKey == "ai.anthropicEnabled")
        #expect(configuration.modelDefaultsKey == "ai.anthropicModel")
        #expect(configuration.maxOutputTokens == 16000)
        #expect(configuration.effort == nil)
    }
}
