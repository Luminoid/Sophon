//
//  LLMModelStoreTests.swift
//  SophonCoreTests
//
//  Unit tests for the generic model store and the adoption helpers every
//  catalog inherits from `LLMModelPreset`, against a fake catalog.
//

import Foundation
import SophonCore
import Testing

private enum FakeModel: LLMModelPreset {
    case alpha
    case beta
    case gamma
    case legacy
    case loopA
    case loopB
    case custom(String)

    static let allStandardCases: [Self] = [.alpha, .beta, .gamma, .legacy, .loopA, .loopB]
    static let recommendedDefault: Self = .beta
    static let recommendedFallback: Self = .alpha
    static let freeAccess: LLMProviderFreeAccess = .none

    var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    var info: LLMModelInfo {
        switch self {
        case .alpha:
            LLMModelInfo(modelID: "fake-alpha", displayName: "Alpha", storageKey: "alpha", tier: .free, generation: 1)
        case .beta:
            LLMModelInfo(modelID: "fake-beta", displayName: "Beta", storageKey: "beta", generation: 2)
        case .gamma:
            LLMModelInfo(modelID: "fake-gamma", displayName: "Gamma", storageKey: "gamma", generation: 3, supportsImageInput: false)
        case .legacy:
            LLMModelInfo(modelID: "fake-legacy", displayName: "Legacy", storageKey: "legacy", lifecycle: .deprecated(shutdown: nil), generation: 0.5)
        case .loopA:
            LLMModelInfo(modelID: "fake-loop-a", displayName: "Loop A", storageKey: "loopA", lifecycle: .retired(nil))
        case .loopB:
            LLMModelInfo(modelID: "fake-loop-b", displayName: "Loop B", storageKey: "loopB", lifecycle: .retired(nil))
        case let .custom(id):
            LLMModelInfo.custom(id)
        }
    }

    var successor: Self? {
        switch self {
        case .legacy: .alpha
        case .loopA: .loopB
        case .loopB: .loopA
        default: nil
        }
    }
}

struct LLMModelStoreTests {
    private static func makeDefaults() -> UserDefaults {
        let name = "SophonCoreTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Could not create UserDefaults suite \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func makeStore(
        defaults: UserDefaults,
        fallbackModel: FakeModel = .alpha,
        availableModels: [FakeModel] = [.alpha, .beta, .gamma]
    ) -> LLMModelStore<FakeModel> {
        LLMModelStore(
            defaults: defaults,
            modelDefaultsKey: "test.model",
            customModelDefaultsKey: "test.customModel",
            defaultModel: .beta,
            fallbackModel: fallbackModel,
            availableModels: availableModels
        )
    }

    // MARK: - Resolution

    @Test
    func `Returns the default when nothing is stored`() {
        #expect(Self.makeStore(defaults: Self.makeDefaults()).current == .beta)
    }

    @Test
    func `Keeps a stored model that is in the catalog`() {
        let defaults = Self.makeDefaults()
        defaults.set("gamma", forKey: "test.model")
        #expect(Self.makeStore(defaults: defaults).current == .gamma)
    }

    @Test
    func `Walks a pruned model to its successor`() {
        let defaults = Self.makeDefaults()
        defaults.set("legacy", forKey: "test.model")
        #expect(Self.makeStore(defaults: defaults).current == .alpha)
    }

    @Test
    func `A successor cycle resolves to the fallback instead of hanging`() {
        let defaults = Self.makeDefaults()
        defaults.set("loopA", forKey: "test.model")
        #expect(Self.makeStore(defaults: defaults).current == .alpha)
    }

    @Test
    func `Unknown storage keys and blank custom IDs fall back`() {
        let unknown = Self.makeDefaults()
        unknown.set("nope", forKey: "test.model")
        #expect(Self.makeStore(defaults: unknown).current == .alpha)

        let blank = Self.makeDefaults()
        blank.set("custom", forKey: "test.model")
        blank.set("  ", forKey: "test.customModel")
        #expect(Self.makeStore(defaults: blank).current == .alpha)
    }

    @Test
    func `Custom models pass through regardless of catalog`() {
        let defaults = Self.makeDefaults()
        defaults.set("custom", forKey: "test.model")
        defaults.set("my-model", forKey: "test.customModel")
        #expect(Self.makeStore(defaults: defaults).current == .custom("my-model"))
    }

    // MARK: - Persistence

    @Test
    func `Select persists the storage key and custom ID`() {
        let defaults = Self.makeDefaults()
        let store = Self.makeStore(defaults: defaults)

        store.select(.gamma)
        #expect(defaults.string(forKey: "test.model") == "gamma")

        store.select(.custom("my-model"))
        #expect(defaults.string(forKey: "test.model") == "custom")
        #expect(defaults.string(forKey: "test.customModel") == "my-model")
    }

    @Test
    func `resetToFallback persists a custom fallback's ID too`() {
        let defaults = Self.makeDefaults()
        defaults.set("gamma", forKey: "test.model")
        let store = Self.makeStore(defaults: defaults, fallbackModel: .custom("safe-model"))

        store.resetToFallback()
        #expect(defaults.string(forKey: "test.model") == "custom")
        #expect(defaults.string(forKey: "test.customModel") == "safe-model")
        #expect(store.current == .custom("safe-model"))
    }

    // MARK: - Preset helpers

    @Test
    func `current excludes deprecated and retired presets in catalog order`() {
        #expect(FakeModel.current == [.alpha, .beta, .gamma])
        #expect(FakeModel.legacy.isDeprecated)
        #expect(!FakeModel.alpha.isDeprecated)
    }

    @Test
    func `Tier, generation, and capability filters narrow current`() {
        #expect(FakeModel.currentFreeTier == [.alpha])
        #expect(FakeModel.current(minimumGeneration: 2) == [.beta, .gamma])
        #expect(FakeModel.currentWithImageInput == [.alpha, .beta])
    }

    @Test
    func `Storage keys round-trip and custom is reconstructed from its ID`() {
        for preset in FakeModel.allStandardCases {
            #expect(FakeModel.from(storageKey: preset.storageKey) == preset)
        }
        #expect(FakeModel.from(storageKey: "custom", customModelID: "x") == .custom("x"))
        #expect(FakeModel.from(storageKey: "custom") == nil)
        #expect(FakeModel.custom("x").isCustom)
        #expect(FakeModel.custom("x").displayName == "x")
    }
}
