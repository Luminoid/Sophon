//
//  GeminiModelTests.swift
//  SophonGeminiTests
//
//  Unit tests for the union model catalog and the per-app resolution behavior of
//  GeminiModelStore (successor walking, fallback, custom pass-through).
//

import Foundation
import SophonGemini
import Testing

struct GeminiModelTests {
    // MARK: - Catalog

    @Test
    func `Standard cases count is 7`() {
        #expect(GeminiModel.allStandardCases.count == 7)
    }

    @Test
    func `All standard cases have non-empty identifiers`() {
        for model in GeminiModel.allStandardCases {
            #expect(!model.modelID.isEmpty)
            #expect(!model.displayName.isEmpty)
            #expect(!model.storageKey.isEmpty)
        }
    }

    @Test
    func `Specific model IDs are correct`() {
        #expect(GeminiModel.gemini25FlashLite.modelID == "gemini-2.5-flash-lite")
        #expect(GeminiModel.gemini25Flash.modelID == "gemini-2.5-flash")
        #expect(GeminiModel.gemini25Pro.modelID == "gemini-2.5-pro")
        #expect(GeminiModel.gemini3Flash.modelID == "gemini-3-flash-preview")
        #expect(GeminiModel.gemini31FlashLite.modelID == "gemini-3.1-flash-lite")
        #expect(GeminiModel.gemini31Pro.modelID == "gemini-3.1-pro-preview")
        #expect(GeminiModel.gemini35Flash.modelID == "gemini-3.5-flash")
    }

    @Test
    func `Custom model uses provided ID`() {
        let model = GeminiModel.custom("my-custom-model-v1")
        #expect(model.modelID == "my-custom-model-v1")
        #expect(model.displayName == "my-custom-model-v1")
        #expect(model.storageKey == "custom")
    }

    @Test
    func `Storage key roundtrip for all standard cases`() {
        for model in GeminiModel.allStandardCases {
            #expect(GeminiModel.from(storageKey: model.storageKey) == model)
        }
    }

    @Test
    func `Storage key roundtrip for custom model`() {
        let reconstructed = GeminiModel.from(storageKey: "custom", customModelID: "test-model")
        #expect(reconstructed == .custom("test-model"))
    }

    @Test
    func `Unknown storage key resolves to nil`() {
        #expect(GeminiModel.from(storageKey: "unknownKey") == nil)
    }

    @Test
    func `Custom key with missing or blank ID resolves to nil`() {
        #expect(GeminiModel.from(storageKey: "custom", customModelID: nil) == nil)
        #expect(GeminiModel.from(storageKey: "custom", customModelID: "  ") == nil)
    }

    @Test
    func `Successor chains terminate for every standard case`() {
        for model in GeminiModel.allStandardCases {
            var seen: Set<String> = []
            var current: GeminiModel? = model
            while let candidate = current {
                #expect(seen.insert(candidate.modelID).inserted, "successor cycle through \(candidate.modelID)")
                current = candidate.successor
            }
        }
    }

    @Test
    func `Deprecated presets map to documented successors`() {
        #expect(GeminiModel.gemini25FlashLite.successor == .gemini31FlashLite)
        #expect(GeminiModel.gemini25Flash.successor == .gemini35Flash)
        #expect(GeminiModel.gemini25Pro.successor == .gemini31Pro)
        #expect(GeminiModel.gemini3Flash.successor == .gemini35Flash)
        #expect(GeminiModel.gemini35Flash.successor == nil)
    }

    // MARK: - Store Resolution

    /// A pruned catalog: only the 3.x presets are offered.
    private func makePrunedStore(defaults: UserDefaults) -> GeminiModelStore {
        GeminiModelStore(configuration: TestSupport.makeConfiguration(
            defaults: defaults,
            defaultModel: .gemini35Flash,
            fallbackModel: .gemini31FlashLite,
            availableModels: [.gemini31FlashLite, .gemini31Pro, .gemini35Flash]
        ))
    }

    /// A full catalog: every preset is offered.
    private func makeFullStore(defaults: UserDefaults) -> GeminiModelStore {
        GeminiModelStore(configuration: TestSupport.makeConfiguration(
            defaults: defaults,
            defaultModel: .gemini31FlashLite,
            fallbackModel: .gemini31FlashLite,
            availableModels: GeminiModel.allStandardCases
        ))
    }

    @Test
    func `Store returns configured default when nothing is stored`() {
        let defaults = TestSupport.makeDefaults()
        #expect(makePrunedStore(defaults: defaults).current == .gemini35Flash)
        #expect(makeFullStore(defaults: defaults).current == .gemini31FlashLite)
    }

    @Test
    func `Store keeps a stored model that is in the catalog`() {
        let defaults = TestSupport.makeDefaults()
        defaults.set("gemini31Pro", forKey: "ai.geminiModel")
        #expect(makePrunedStore(defaults: defaults).current == .gemini31Pro)
    }

    @Test
    func `Store walks legacy keys to successors under a pruned catalog`() {
        let cases: [(stored: String, expected: GeminiModel)] = [
            ("gemini25FlashLite", .gemini31FlashLite),
            ("gemini25Flash", .gemini35Flash),
            ("gemini25Pro", .gemini31Pro),
            ("gemini3Flash", .gemini35Flash),
        ]
        for (stored, expected) in cases {
            let defaults = TestSupport.makeDefaults()
            defaults.set(stored, forKey: "ai.geminiModel")
            #expect(makePrunedStore(defaults: defaults).current == expected)
        }
    }

    @Test
    func `Store keeps legacy models under a full catalog`() {
        let defaults = TestSupport.makeDefaults()
        defaults.set("gemini25Flash", forKey: "ai.geminiModel")
        #expect(makeFullStore(defaults: defaults).current == .gemini25Flash)
    }

    @Test
    func `Store falls back on unknown stored key`() {
        let defaults = TestSupport.makeDefaults()
        defaults.set("someRetiredKey", forKey: "ai.geminiModel")
        #expect(makePrunedStore(defaults: defaults).current == .gemini31FlashLite)
    }

    @Test
    func `Store falls back on blank custom ID`() {
        let defaults = TestSupport.makeDefaults()
        defaults.set("custom", forKey: "ai.geminiModel")
        defaults.set("   ", forKey: "ai.geminiCustomModel")
        #expect(makePrunedStore(defaults: defaults).current == .gemini31FlashLite)
    }

    @Test
    func `Store passes custom models through regardless of catalog`() {
        let defaults = TestSupport.makeDefaults()
        defaults.set("custom", forKey: "ai.geminiModel")
        defaults.set("my-model", forKey: "ai.geminiCustomModel")
        #expect(makePrunedStore(defaults: defaults).current == .custom("my-model"))
    }

    @Test
    func `Select persists storage key and custom ID`() {
        let defaults = TestSupport.makeDefaults()
        let store = makeFullStore(defaults: defaults)

        store.select(.gemini35Flash)
        #expect(defaults.string(forKey: "ai.geminiModel") == "gemini35Flash")

        store.select(.custom("my-model"))
        #expect(defaults.string(forKey: "ai.geminiModel") == "custom")
        #expect(defaults.string(forKey: "ai.geminiCustomModel") == "my-model")
    }

    @Test
    func `resetToFallback persists the configured fallback`() {
        let defaults = TestSupport.makeDefaults()
        defaults.set("gemini35Flash", forKey: "ai.geminiModel")
        let store = makePrunedStore(defaults: defaults)

        store.resetToFallback()
        #expect(defaults.string(forKey: "ai.geminiModel") == "gemini31FlashLite")
        #expect(store.current == .gemini31FlashLite)
    }
}
