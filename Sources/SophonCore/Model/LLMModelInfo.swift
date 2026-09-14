//
//  LLMModelInfo.swift
//  SophonCore
//
//  Catalog metadata every model preset carries: identity, lifecycle, free-tier
//  membership, pricing, and the capability flags the clients consult when
//  building requests. The facts that used to live in doc comments, now
//  machine-checkable.
//

import Foundation

/// Where a model stands in its provider's lifecycle.
public enum LLMModelLifecycle: Sendable, Equatable {
    /// Served, no shutdown announced.
    case current
    /// Shutdown announced (date when the provider published one). Still served
    /// until then; excluded from `current`.
    case deprecated(shutdown: Date?)
    /// No longer served; kept only so stored selections resolve via `successor`.
    case retired(Date?)

    public var isCurrent: Bool {
        if case .current = self { return true }
        return false
    }
}

/// Whether a model is part of the provider's permanent free tier.
public enum LLMModelTier: Sendable, Equatable {
    /// Callable on a key with no billing enabled, indefinitely (rate-limited).
    case free
    /// Billed per token; a new-user quota or trial credit may still cover it.
    case paid
}

public enum LLMCurrency: String, Sendable {
    case usd = "USD"
    case cny = "CNY"
}

/// List price per 1M tokens, in the currency the provider bills in.
public struct LLMModelPricing: Sendable, Equatable {
    public let inputPerMillion: Double
    public let outputPerMillion: Double
    public let currency: LLMCurrency

    public init(input: Double, output: Double, currency: LLMCurrency = .usd) {
        inputPerMillion = input
        outputPerMillion = output
        self.currency = currency
    }
}

/// How a provider can be used without paying, at the provider level.
public enum LLMProviderFreeAccess: Sendable, Equatable {
    /// A standing free tier: some models are callable indefinitely without billing.
    case permanentTier(note: String)
    /// A one-time allowance for new accounts (per-model token quota with an expiry).
    case newUserQuota(note: String)
    /// A one-time signup credit spent at list price.
    case trialCredit(note: String)
    /// Paid from the first token.
    case none

    public var note: String? {
        switch self {
        case let .permanentTier(note), let .newUserQuota(note), let .trialCredit(note): note
        case .none: nil
        }
    }

    public var isPermanent: Bool {
        if case .permanentTier = self { return true }
        return false
    }
}

public struct LLMModelInfo: Sendable, Equatable {
    /// The identifier the API expects in requests.
    public let modelID: String
    public let displayName: String
    /// Stable persistence key; never changes once a consumer app has shipped it.
    public let storageKey: String
    public let lifecycle: LLMModelLifecycle
    public let tier: LLMModelTier
    /// Model generation as the provider numbers it (Gemini 3.8, GPT 5.6,
    /// Claude 4.6), for "everything from generation N on" filters.
    public let generation: Double?
    public let releaseDate: Date?
    public let pricing: LLMModelPricing?
    public let supportsImageInput: Bool
    /// Whether the API accepts a `temperature` for this model; several
    /// reasoning models reject sampling parameters outright.
    public let supportsTemperature: Bool
    public let contextWindow: Int?

    public init(
        modelID: String,
        displayName: String,
        storageKey: String,
        lifecycle: LLMModelLifecycle = .current,
        tier: LLMModelTier = .paid,
        generation: Double? = nil,
        releaseDate: Date? = nil,
        pricing: LLMModelPricing? = nil,
        supportsImageInput: Bool = true,
        supportsTemperature: Bool = true,
        contextWindow: Int? = nil
    ) {
        self.modelID = modelID
        self.displayName = displayName
        self.storageKey = storageKey
        self.lifecycle = lifecycle
        self.tier = tier
        self.generation = generation
        self.releaseDate = releaseDate
        self.pricing = pricing
        self.supportsImageInput = supportsImageInput
        self.supportsTemperature = supportsTemperature
        self.contextWindow = contextWindow
    }

    /// Metadata for a caller-supplied model ID: nothing is known beyond the ID,
    /// so clients treat it as current, paid, image-capable, and skip sampling
    /// parameters the model might reject.
    public static func custom(_ modelID: String) -> Self {
        Self(
            modelID: modelID,
            displayName: modelID,
            storageKey: "custom",
            lifecycle: .current,
            tier: .paid,
            supportsImageInput: true,
            supportsTemperature: false
        )
    }

    /// A calendar day at midnight UTC, for catalog release and shutdown dates.
    /// Traps on an impossible date: catalog literals are developer data, and
    /// every catalog is read in tests, so a typo fails there rather than
    /// silently becoming a date in the distant past.
    public static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else {
            preconditionFailure("Impossible catalog date \(year)-\(month)-\(day)")
        }
        return date
    }
}
