//
//  LLMCatalogAuditTests.swift
//  SophonCoreTests
//
//  Unit tests for the catalog audit: a consistent fake catalog passes, and
//  each violation class is reported for a deliberately broken one.
//

import Foundation
import SophonCore
import Testing

private enum CleanModel: LLMModelPreset {
    case old
    case new
    case newer
    case custom(String)

    static let allStandardCases: [Self] = [.old, .new, .newer]
    static let recommendedDefault: Self = .newer
    static let recommendedFallback: Self = .new
    static let freeAccess: LLMProviderFreeAccess = .permanentTier(note: "test")

    var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    var info: LLMModelInfo {
        switch self {
        case .old: LLMModelInfo(modelID: "old", displayName: "Old", storageKey: "old", lifecycle: .retired(nil))
        case .new: LLMModelInfo(modelID: "new", displayName: "New", storageKey: "new")
        case .newer: LLMModelInfo(modelID: "newer", displayName: "Newer", storageKey: "newer")
        case let .custom(id): LLMModelInfo.custom(id)
        }
    }

    var successor: Self? {
        self == .old ? .new : nil
    }
}

private enum BrokenModel: LLMModelPreset {
    case one
    case two
    case orphan
    case loopA
    case loopB
    case custom(String)

    static let allStandardCases: [Self] = [.one, .two, .orphan, .loopA, .loopB]
    static let recommendedDefault: Self = .orphan
    static let recommendedFallback: Self = .orphan
    static let freeAccess: LLMProviderFreeAccess = .none

    var customModelID: String? {
        if case let .custom(id) = self { return id }
        return nil
    }

    var info: LLMModelInfo {
        switch self {
        case .one: LLMModelInfo(modelID: "one", displayName: "One", storageKey: "dup")
        case .two: LLMModelInfo(modelID: "two", displayName: "Two", storageKey: "dup")
        case .orphan: LLMModelInfo(modelID: "orphan", displayName: "Orphan", storageKey: "orphan", lifecycle: .deprecated(shutdown: nil))
        case .loopA: LLMModelInfo(modelID: "loop-a", displayName: "A", storageKey: "loopA", lifecycle: .retired(nil))
        case .loopB: LLMModelInfo(modelID: "loop-b", displayName: "B", storageKey: "loopB", lifecycle: .retired(nil))
        case let .custom(id): LLMModelInfo.custom(id)
        }
    }

    var successor: Self? {
        switch self {
        case .loopA: .loopB
        case .loopB: .loopA
        default: nil
        }
    }
}

struct LLMCatalogAuditTests {
    @Test
    func `A consistent catalog has no violations`() {
        #expect(LLMCatalogAudit.violations(in: CleanModel.self).isEmpty)
    }

    @Test
    func `Each violation class is reported`() {
        let violations = LLMCatalogAudit.violations(in: BrokenModel.self)

        #expect(violations.contains { $0.contains("duplicate storage key") })
        #expect(violations.contains { $0.contains("does not round-trip") })
        #expect(violations.contains { $0.contains("orphan") && $0.contains("needs a successor chain") })
        #expect(violations.contains { $0.contains("cycles") })
        #expect(violations.contains { $0.contains("recommendedDefault") && $0.contains("not current") })
        #expect(violations.contains { $0.contains("must differ") })
    }
}
