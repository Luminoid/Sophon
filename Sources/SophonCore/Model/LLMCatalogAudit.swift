//
//  LLMCatalogAudit.swift
//  SophonCore
//
//  Invariants every model catalog must hold, as a list of violations so a
//  single test per catalog can lock them: unique keys and IDs, storage-key
//  round-tripping, successor chains that end at a current preset, and
//  recommended default/fallback presets that are current and distinct.
//

import Foundation

public enum LLMCatalogAudit {
    /// Empty when the catalog is consistent; otherwise one line per violation.
    public static func violations<Model: LLMModelPreset>(in _: Model.Type) -> [String] {
        var violations: [String] = []
        let presets = Model.allStandardCases

        var seenKeys: Set<String> = []
        var seenIDs: Set<String> = []
        for preset in presets {
            if preset.isCustom {
                violations.append("\(preset.modelID): custom values do not belong in allStandardCases")
            }
            if !seenKeys.insert(preset.storageKey).inserted {
                violations.append("\(preset.modelID): duplicate storage key \(preset.storageKey)")
            }
            if !seenIDs.insert(preset.modelID).inserted {
                violations.append("\(preset.modelID): duplicate model ID")
            }
            if Model.from(storageKey: preset.storageKey) != preset {
                violations.append("\(preset.modelID): storage key \(preset.storageKey) does not round-trip")
            }
            violations.append(contentsOf: successorViolations(of: preset, in: Model.self))
        }

        for (name, preset) in [("recommendedDefault", Model.recommendedDefault), ("recommendedFallback", Model.recommendedFallback)] {
            if !presets.contains(preset) {
                violations.append("\(name) \(preset.modelID) is not in allStandardCases")
            }
            if !preset.info.lifecycle.isCurrent {
                violations.append("\(name) \(preset.modelID) is not current")
            }
        }
        if Model.recommendedDefault == Model.recommendedFallback {
            violations.append("recommendedDefault and recommendedFallback must differ")
        }

        return violations
    }

    private static func successorViolations<Model: LLMModelPreset>(of preset: Model, in _: Model.Type) -> [String] {
        var seen: Set<String> = [preset.modelID]
        var cursor = preset
        while let next = cursor.successor {
            if !seen.insert(next.modelID).inserted {
                return ["\(preset.modelID): successor chain cycles through \(next.modelID)"]
            }
            if !Model.allStandardCases.contains(next) {
                return ["\(preset.modelID): successor \(next.modelID) is not a catalog preset"]
            }
            cursor = next
        }
        if preset.isDeprecated, cursor.isDeprecated {
            return ["\(preset.modelID): deprecated preset needs a successor chain ending at a current preset (ends at \(cursor.modelID))"]
        }
        return []
    }
}
