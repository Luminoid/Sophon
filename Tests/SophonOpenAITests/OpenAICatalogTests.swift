//
//  OpenAICatalogTests.swift
//  SophonOpenAITests
//
//  Locks the nine OpenAI-compatible catalogs: audit invariants, recommended
//  presets, free-tier membership where a provider has a permanent tier,
//  endpoint presets (URLs, wire format, structured-output mode, derived
//  defaults keys), and the regional splits.
//

import Foundation
import SophonCore
import SophonOpenAI
import Testing

struct OpenAICatalogTests {
    @Test
    func `Every catalog passes the audit`() {
        #expect(LLMCatalogAudit.violations(in: OpenAIModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: GroqModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: MistralModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: OpenRouterModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: DeepSeekModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: QwenModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: GLMModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: KimiModel.self).isEmpty)
        #expect(LLMCatalogAudit.violations(in: DoubaoModel.self).isEmpty)
    }

    @Test
    func `Providers with a permanent free tier recommend free models`() {
        #expect(GroqModel.freeAccess.isPermanent)
        #expect(GroqModel.recommendedDefault.hasFreeTier)
        #expect(GroqModel.recommendedFallback.hasFreeTier)
        #expect(GLMModel.freeAccess.isPermanent)
        #expect(GLMModel.recommendedDefault.hasFreeTier)
        #expect(GLMModel.recommendedFallback.hasFreeTier)
        #expect(MistralModel.freeAccess.isPermanent)
        #expect(MistralModel.currentFreeTier == MistralModel.current)
        #expect(OpenRouterModel.recommendedDefault.hasFreeTier)
        #expect(!OpenRouterModel.auto.hasFreeTier)
    }

    @Test
    func `Paid providers declare their free access honestly`() {
        #expect(!OpenAIModel.freeAccess.isPermanent)
        #expect(OpenAIModel.currentFreeTier.isEmpty)
        #expect(!DeepSeekModel.freeAccess.isPermanent)
        if case .newUserQuota = QwenModel.freeAccess {} else { Issue.record("Qwen should be a new-user quota") }
        if case .newUserQuota = DoubaoModel.freeAccess {} else { Issue.record("Doubao should be a new-user quota") }
        if case .trialCredit = KimiModel.freeAccess {} else { Issue.record("Kimi should be a trial credit") }
    }

    @Test
    func `OpenAI presets carry lifecycle, successors, and sampling flags`() {
        #expect(OpenAIModel.recommendedDefault == .gpt56Luna)
        #expect(OpenAIModel.gpt5.info.lifecycle == .deprecated(shutdown: LLMModelInfo.day(2026, 12, 11)))
        #expect(OpenAIModel.gpt5.successor == .gpt56Sol)
        #expect(OpenAIModel.gpt5Nano.successor == .gpt56Luna)
        #expect(!OpenAIModel.current.contains(.gpt5))
        #expect(OpenAIModel.current(minimumGeneration: 5.6) == [.gpt6Astra, .gpt56Sol, .gpt56Terra, .gpt56Luna])
        #expect(!OpenAIModel.gpt56Luna.info.supportsTemperature)
        #expect(OpenAIModel.gpt41.info.supportsTemperature)
        #expect(OpenAIModel.gpt6Astra.modelID == "gpt-6-astra")
    }

    @Test
    func `DeepSeek retired aliases resolve to current models`() {
        #expect(DeepSeekModel.deepseekChat.successor == .deepseekFlash)
        #expect(DeepSeekModel.deepseekReasoner.successor == .deepseekV4Pro)
        #expect(DeepSeekModel.deepseekV4Flash.successor == .deepseekFlash)
        #expect(DeepSeekModel.current == [.deepseekFlash, .deepseekV4Pro])
        #expect(DeepSeekModel.currentWithImageInput == [.deepseekFlash])
    }

    @Test
    func `Endpoint presets carry the verified base URLs and dialects`() {
        #expect(OpenAIModel.defaultEndpoint.baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(OpenAIModel.defaultEndpoint.wireFormat == .responses)
        #expect(OpenAIModel.defaultEndpoint.structuredOutputMode == .jsonSchema)
        #expect(OpenAIModel.defaultEndpoint.maxTokensField == .maxCompletionTokens)

        #expect(GroqModel.defaultEndpoint.baseURL.absoluteString == "https://api.groq.com/openai/v1")
        #expect(GroqModel.defaultEndpoint.wireFormat == .chatCompletions)
        #expect(GroqModel.defaultEndpoint.url(path: "chat/completions").absoluteString == "https://api.groq.com/openai/v1/chat/completions")

        #expect(MistralModel.defaultEndpoint.baseURL.absoluteString == "https://api.mistral.ai/v1")
        #expect(OpenRouterModel.defaultEndpoint.baseURL.absoluteString == "https://openrouter.ai/api/v1")
        #expect(DeepSeekModel.defaultEndpoint.baseURL.absoluteString == "https://api.deepseek.com/v1")
        #expect(DeepSeekModel.defaultEndpoint.structuredOutputMode == .jsonObject)
        #expect(DoubaoModel.defaultEndpoint.baseURL.absoluteString == "https://ark.cn-beijing.volces.com/api/v3")
    }

    @Test
    func `Regional providers split China and international endpoints`() {
        #expect(QwenModel.endpoint(region: .china).baseURL.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1")
        #expect(QwenModel.endpoint(region: .international).baseURL.absoluteString == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")
        #expect(QwenModel.defaultEndpoint == QwenModel.endpoint(region: .international))
        #expect(GLMModel.endpoint(region: .china).baseURL.absoluteString == "https://open.bigmodel.cn/api/paas/v4")
        #expect(GLMModel.endpoint(region: .international).baseURL.absoluteString == "https://api.z.ai/api/paas/v4")
        #expect(KimiModel.endpoint(region: .china).baseURL.absoluteString == "https://api.moonshot.cn/v1")
        #expect(KimiModel.endpoint(region: .international).baseURL.absoluteString == "https://api.moonshot.ai/v1")
        // Same key prefix in both regions, so a stored selection survives a region switch.
        #expect(QwenModel.endpoint(region: .china).keyPrefix == QwenModel.endpoint(region: .international).keyPrefix)
    }

    @Test
    func `Defaults keys derive from the endpoint key prefix unless overridden`() {
        let derived = DeepSeekClientConfiguration(keychainAccount: "com.sophon.tests.deepSeek")
        #expect(derived.enabledDefaultsKey == "ai.deepSeekEnabled")
        #expect(derived.modelDefaultsKey == "ai.deepSeekModel")
        #expect(derived.customModelDefaultsKey == "ai.deepSeekCustomModel")
        #expect(derived.defaultModel == .deepseekFlash)
        #expect(derived.availableModels == DeepSeekModel.current)

        let overridden = OpenAIClientConfiguration(keychainAccount: "com.sophon.tests.openAI", modelDefaultsKey: "custom.model")
        #expect(overridden.enabledDefaultsKey == "ai.openAIEnabled")
        #expect(overridden.modelDefaultsKey == "custom.model")
    }

    @Test
    func `Key prefixes are unique per provider and every catalog carries a key hint`() {
        let endpoints: [OpenAIEndpoint] = [
            OpenAIModel.defaultEndpoint, GroqModel.defaultEndpoint, MistralModel.defaultEndpoint, OpenRouterModel.defaultEndpoint,
            DeepSeekModel.defaultEndpoint, QwenModel.defaultEndpoint, GLMModel.defaultEndpoint, KimiModel.defaultEndpoint, DoubaoModel.defaultEndpoint,
        ]
        let prefixes = endpoints.map(\.keyPrefix)
        #expect(Set(prefixes).count == prefixes.count, "a duplicated keyPrefix would share another provider's selection: \(prefixes)")
        #expect(endpoints.allSatisfy { $0.keyHintURL != nil })

        #expect(OpenAIModel.keyHintURL == OpenAIModel.defaultEndpoint.keyHintURL)
        #expect(QwenModel.keyHintURL != nil)
        #expect(DoubaoModel.keyHintURL != nil)
    }
}
