//
//  LLMClient.swift
//  SophonCore
//
//  The cross-provider client surface: one-call structured and plain-text
//  generation plus live model listing. Apps that let users pick a provider can
//  hold `any LLMClient`; the provider-specific builders and `send` closures
//  stay on the concrete clients.
//

import Foundation

/// A model the provider currently serves, as reported by its listing endpoint.
public struct LLMRemoteModel: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String?
    public let inputTokenLimit: Int?
    public let outputTokenLimit: Int?

    public init(id: String, displayName: String? = nil, inputTokenLimit: Int? = nil, outputTokenLimit: Int? = nil) {
        self.id = id
        self.displayName = displayName
        self.inputTokenLimit = inputTokenLimit
        self.outputTokenLimit = outputTokenLimit
    }
}

@MainActor
public protocol LLMClient: AnyObject {
    /// Human-readable provider (or endpoint) name, for pickers and logs.
    var providerDisplayName: String { get }
    /// The model ID the next request will target.
    var currentModelID: String { get }

    func loadAPIKey() -> String?

    /// One-call structured generation: prompt (+ optional media parts) in,
    /// decoded result out. Loads the API key itself.
    func generateStructured<T: Decodable>(
        _ type: T.Type,
        label: String,
        prompt: String,
        parts: [LLMPart],
        schema: LLMSchema?,
        temperature: Double,
        retryPolicy: LLMRetryPolicy?
    ) async throws -> T

    /// One-call plain-text generation over explicit role-tagged messages.
    func generateText(
        label: String,
        contents: [LLMMessage],
        temperature: Double,
        retryPolicy: LLMRetryPolicy?
    ) async throws -> String

    /// The models the provider serves right now, from its listing endpoint.
    func listModels() async throws -> [LLMRemoteModel]
}
