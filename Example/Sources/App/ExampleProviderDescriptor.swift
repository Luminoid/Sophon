//
//  ExampleProviderDescriptor.swift
//  SophonExample
//
//  A provider as the demo pages see it: the cross-provider client plus the few
//  typed operations the settings page needs, captured as closures so the pages
//  never depend on a catalog type.
//

import Foundation
import SophonCore
import SophonOpenAI

// MARK: - Model Option

/// One row of a provider's model picker.
struct ExampleModelOption {
    let title: String
    /// Catalog facts worth a glance before picking: context window, list
    /// price, release date, and a lifecycle or free-tier marker.
    let subtitle: String?
    let isSelected: Bool
    let select: @MainActor () -> Void

    static func subtitle(for info: LLMModelInfo) -> String? {
        var parts: [String] = []
        if let contextWindow = info.contextWindow {
            parts.append("\(compactTokenCount(contextWindow)) context")
        }
        if let pricing = info.pricing {
            let input = price(pricing.inputPerMillion, in: pricing.currency)
            let output = price(pricing.outputPerMillion, in: pricing.currency)
            parts.append("\(input) / \(output) per 1M tokens")
        }
        if let releaseDate = info.releaseDate {
            // Catalog dates are midnight UTC; format in UTC so western time zones do not show the day before.
            parts.append(releaseDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt)))
        }
        switch info.lifecycle {
        case .current:
            if info.tier == .free { parts.append("free tier") }
        case .deprecated:
            parts.append("deprecated")
        case .retired:
            parts.append("retired")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 1_047_576 reads as "1M", 262_144 as "262K".
    private static func compactTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return "\(Int((Double(count) / 1_000_000).rounded()))M"
        }
        if count >= 1000 {
            return "\(Int((Double(count) / 1000).rounded()))K"
        }
        return String(count)
    }

    private static func price(_ perMillion: Double, in currency: LLMCurrency) -> String {
        switch currency {
        case .usd: "$" + perMillion.formatted(.number.precision(.fractionLength(2 ... 3)))
        case .cny: "¥" + perMillion.formatted(.number.precision(.fractionLength(0 ... 3)))
        }
    }
}

// MARK: - Provider Descriptor

@MainActor
struct ExampleProviderDescriptor {
    static let defaultListModelsNote = "Every model the provider serves right now, from its listing endpoint."

    let title: String
    let client: any LLMClient
    let configuration: any LLMProviderConfiguration
    let freeAccess: LLMProviderFreeAccess
    /// Where the user gets an API key (the catalog's `keyHintURL`), or empty when the provider publishes none.
    let keyHint: String
    /// What `listModels` returns, for the Settings footnote.
    let listModelsNote: String
    let listModels: @MainActor () async throws -> [LLMRemoteModel]
    let modelOptions: () -> [ExampleModelOption]
    let selectCustomModel: (String) -> Void
    let currentModelName: () -> String
    let isCustomModelSelected: () -> Bool

    /// - Parameters:
    ///   - keyHintURL: Overrides the catalog's `keyHintURL`; a region-specific endpoint may publish its own.
    ///   - listModels: Overrides the client's `listModels()`; OpenRouter lists only its free roster.
    init<Model: LLMModelPreset>(
        title: String,
        client: any LLMClient,
        configuration: any LLMProviderConfiguration,
        store: LLMModelStore<Model>,
        keyHintURL: URL? = nil,
        listModels: (@MainActor () async throws -> [LLMRemoteModel])? = nil,
        listModelsNote: String = Self.defaultListModelsNote
    ) {
        self.title = title
        self.client = client
        self.configuration = configuration
        freeAccess = Model.freeAccess
        keyHint = (keyHintURL ?? Model.keyHintURL)?.absoluteString ?? ""
        self.listModelsNote = listModelsNote
        self.listModels = listModels ?? { try await client.listModels() }
        modelOptions = {
            let current = store.current
            return store.availableModels.map { model in
                ExampleModelOption(title: model.displayName, subtitle: ExampleModelOption.subtitle(for: model.info), isSelected: model == current) {
                    store.select(model)
                }
            }
        }
        selectCustomModel = { store.select(Model.custom($0)) }
        currentModelName = { store.current.displayName }
        isCustomModelSelected = { store.current.isCustom }
    }

    /// Descriptor for an OpenAI-compatible client, keyed by its endpoint. The
    /// endpoint's key hint wins when it has one (region-specific consoles);
    /// otherwise the catalog's default-endpoint hint applies.
    init(
        title: String,
        client: OpenAICompatibleClient<some OpenAICompatibleModel>,
        listModels: (@MainActor () async throws -> [LLMRemoteModel])? = nil,
        listModelsNote: String = Self.defaultListModelsNote
    ) {
        self.init(
            title: title,
            client: client,
            configuration: client.configuration,
            store: client.modelStore,
            keyHintURL: client.configuration.endpoint.keyHintURL,
            listModels: listModels,
            listModelsNote: listModelsNote
        )
    }
}
