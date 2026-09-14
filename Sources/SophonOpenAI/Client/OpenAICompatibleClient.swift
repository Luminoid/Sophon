//
//  OpenAICompatibleClient.swift
//  SophonOpenAI
//
//  Networking layer for OpenAI and every OpenAI-compatible endpoint: request
//  building for both wire formats, policy-driven retry via the shared
//  `LLMRetryLoop`, structured/plain-text decoding with brace repair for
//  responses that end early without a truncation signal, and live model
//  listing. Generic over the provider's catalog.
//

import Foundation
import SophonCore

@MainActor
public final class OpenAICompatibleClient<Model: OpenAICompatibleModel>: LLMClient {
    public let configuration: OpenAICompatibleConfiguration<Model>
    public let modelStore: LLMModelStore<Model>
    private let session: URLSession
    private let ownsSession: Bool

    /// Build a client from a configuration. Pass a custom `session` to add
    /// debug network logging or, in tests, a `URLProtocol` mock; nil builds an
    /// ephemeral one from the configuration's timeouts (no shared URL cache or
    /// cookie jar, so a cached `GET /models` can never go stale on disk).
    public init(configuration: OpenAICompatibleConfiguration<Model>, session: URLSession? = nil) {
        self.configuration = configuration
        modelStore = configuration.modelStore
        if let session {
            self.session = session
            ownsSession = false
        } else {
            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout
            sessionConfig.timeoutIntervalForResource = configuration.resourceTimeout
            self.session = URLSession(configuration: sessionConfig)
            ownsSession = true
        }
    }

    deinit {
        if ownsSession { session.finishTasksAndInvalidate() }
    }

    public var providerDisplayName: String { configuration.endpoint.displayName }

    public var currentModelID: String { modelStore.current.modelID }

    private var endpoint: OpenAIEndpoint { configuration.endpoint }

    // MARK: - API Key

    public func loadAPIKey() -> String? {
        configuration.loadAPIKey()
    }

    /// The stored key, or `apiKeyMissing` / `apiKeyInaccessible` (locked Keychain).
    private func requireAPIKey() throws -> String {
        try configuration.requireAPIKey(
            missing: { OpenAIError.apiKeyMissing(provider: providerDisplayName) },
            inaccessible: OpenAIError.apiKeyInaccessible
        )
    }

    // MARK: - Request Building & Execution

    /// Build a single-turn request. Media parts (images, PDFs) go before the
    /// instruction text so the model reads the prompt in the context of the
    /// already-ingested documents. Body encoding runs on the caller's
    /// executor; the `generate*` conveniences encode off-main instead.
    public func buildRequest(
        parts: [LLMPart] = [],
        promptText: String,
        apiKey: String,
        modelID: String? = nil,
        responseSchema: LLMSchema? = nil,
        temperature: Double = 0.1
    ) throws -> URLRequest {
        try buildMultiTurnRequest(
            contents: [LLMMessage(parts: parts + [.text(promptText)], role: .user)],
            apiKey: apiKey,
            modelID: modelID,
            responseSchema: responseSchema,
            temperature: temperature
        )
    }

    /// Build a multi-turn request from explicit role-tagged messages.
    public func buildMultiTurnRequest(
        contents: [LLMMessage],
        apiKey: String,
        modelID: String? = nil,
        responseSchema: LLMSchema? = nil,
        temperature: Double = 0.3
    ) throws -> URLRequest {
        var request = try makeBaseRequest(apiKey: apiKey, path: endpoint.wireFormat.generationPath, method: "POST")
        let plan = makePlan(contents: contents, modelID: modelID, responseSchema: responseSchema, temperature: temperature)
        request.httpBody = try JSONEncoder().encode(OpenAIRequestBodies.body(for: plan))
        return request
    }

    private func makePlan(contents: [LLMMessage], modelID: String?, responseSchema: LLMSchema?, temperature: Double) -> OpenAIRequestPlan {
        let resolvedModelID = modelID ?? modelStore.current.modelID
        let preset = Model.allStandardCases.first { $0.modelID == resolvedModelID } ?? Model.custom(resolvedModelID)
        if contents.contains(where: { $0.role == .system && $0.parts.contains(where: \.isMedia) }) {
            log(.warning, "\(providerDisplayName): media parts in a system message are dropped; the wire format carries system text only")
        }
        return OpenAIRequestPlan(
            endpoint: endpoint,
            modelID: resolvedModelID,
            messages: contents,
            temperature: preset.info.supportsTemperature ? temperature : nil,
            maxOutputTokens: configuration.maxOutputTokens,
            schema: responseSchema
        )
    }

    /// JSON-encode a request body off the calling executor. Multi-image bodies
    /// run to tens of megabytes of base64 text, and escaping them is measurable
    /// main-thread work.
    nonisolated static func encodeBody(_ plan: OpenAIRequestPlan) async throws -> Data {
        try await Task.detached { try JSONEncoder().encode(OpenAIRequestBodies.body(for: plan)) }.value
    }

    private func makeBaseRequest(apiKey: String, path: String, method: String) throws -> URLRequest {
        // The key rides in a header, never in the URL: NSURLError userInfo
        // embeds the failing URL verbatim, so a query-string key would leak
        // into every transport-error log.
        let url = endpoint.url(path: path)
        guard url.scheme != nil, url.host() != nil else {
            throw OpenAIError.invalidEndpoint(url.absoluteString)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(endpoint.authorizationValuePrefix + apiKey, forHTTPHeaderField: endpoint.authorizationHeaderField)
        for (field, value) in endpoint.extraHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        if let appName = configuration.appName {
            request.setValue(appName, forHTTPHeaderField: "X-Title")
        }
        if let appURL = configuration.appURL {
            request.setValue(appURL.absoluteString, forHTTPHeaderField: "HTTP-Referer")
        }
        return request
    }

    public func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log(.error, "\(providerDisplayName) API request failed: \(error.localizedDescription)")
            throw OpenAIError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        return (data, httpResponse)
    }

    // MARK: - Retry-Aware Send

    /// Send a structured (JSON) request with automatic transient-error retry and model fallback.
    /// `buildRequest` is invoked once per attempt with the variant (image size + model ID) the
    /// retry loop wants for that attempt, so a retry can re-encode smaller images or swap models.
    /// Errors the closure throws that are not `OpenAIError` propagate as-is, without retry.
    public func send<T: Decodable>(
        _ type: T.Type,
        label: String,
        retryPolicy: LLMRetryPolicy? = nil,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest
    ) async throws -> T {
        try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: true, buildRequest: buildRequest) { data, response in
            try self.decodeResponse(type, data: data, httpResponse: response, label: label)
        }
    }

    /// Send a multi-turn / plain-text request with the same retry behavior.
    public func sendPlainText(
        label: String,
        retryPolicy: LLMRetryPolicy? = nil,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest
    ) async throws -> String {
        try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: true, buildRequest: buildRequest) { data, response in
            try self.extractPlainTextResponse(data: data, httpResponse: response)
        }
    }

    // MARK: - Conveniences

    /// One-call structured generation: prompt (+ optional media parts) in,
    /// decoded result out. Loads the API key itself and encodes the request body
    /// off-main. The parts are pre-encoded, so an oversized request fails at
    /// once rather than re-sending the same body.
    public func generateStructured<T: Decodable>(
        _ type: T.Type,
        label: String,
        prompt: String,
        parts: [LLMPart] = [],
        schema: LLMSchema? = nil,
        temperature: Double = 0.1,
        retryPolicy: LLMRetryPolicy? = nil
    ) async throws -> T {
        let apiKey = try requireAPIKey()
        return try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: false, buildRequest: { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, path: endpoint.wireFormat.generationPath, method: "POST")
            let plan = makePlan(
                contents: [LLMMessage(parts: parts + [.text(prompt)], role: .user)],
                modelID: variant.modelID,
                responseSchema: schema,
                temperature: temperature
            )
            request.httpBody = try await Self.encodeBody(plan)
            return request
        }, decode: { data, response in
            try self.decodeResponse(type, data: data, httpResponse: response, label: label)
        })
    }

    /// One-call plain-text generation over explicit role-tagged messages
    /// (multi-turn conversations, free-form reports). Encodes the request body
    /// off-main.
    public func generateText(
        label: String,
        contents: [LLMMessage],
        temperature: Double = 0.3,
        retryPolicy: LLMRetryPolicy? = nil
    ) async throws -> String {
        let apiKey = try requireAPIKey()
        return try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: false, buildRequest: { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, path: endpoint.wireFormat.generationPath, method: "POST")
            let plan = makePlan(contents: contents, modelID: variant.modelID, responseSchema: nil, temperature: temperature)
            request.httpBody = try await Self.encodeBody(plan)
            return request
        }, decode: { data, response in
            try self.extractPlainTextResponse(data: data, httpResponse: response)
        })
    }

    private func sendWithRetry<R>(
        label: String,
        policy: LLMRetryPolicy,
        canDownscaleImages: Bool,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest,
        decode: (Data, HTTPURLResponse) throws -> R
    ) async throws -> R {
        try await LLMRetryLoop.run(
            providerName: providerDisplayName,
            label: label,
            policy: policy,
            initialModelID: modelStore.current.modelID,
            fallbackModelID: configuration.fallbackModel.modelID,
            canDownscaleImages: canDownscaleImages,
            log: { level, message in self.log(level, message) },
            buildRequest: buildRequest,
            perform: { request in try await self.performRequest(request) },
            decode: decode
        )
    }

    // MARK: - Model Listing

    /// The models the endpoint serves right now (`GET /models`). No retry.
    public func listModels() async throws -> [LLMRemoteModel] {
        try await listModels(apiKey: requireAPIKey())
    }

    /// `listModels()` with an explicit key, for callers that hold the key themselves.
    public func listModels(apiKey: String) async throws -> [LLMRemoteModel] {
        let request = try makeBaseRequest(apiKey: apiKey, path: "models", method: "GET")
        let (data, httpResponse) = try await performRequest(request)
        try throwForStatus(httpResponse, data: data, resetsRetiredModel: false)
        do {
            let list = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)
            return (list.data ?? []).map(\.remoteModel)
        } catch {
            log(.error, "Failed to decode \(providerDisplayName) model list: \(error.localizedDescription)")
            throw OpenAIError.invalidResponse
        }
    }

    // MARK: - Response Parsing

    public func decodeResponse<T: Decodable>(
        _ type: T.Type,
        data: Data,
        httpResponse: HTTPURLResponse,
        label: String
    ) throws -> T {
        let text = try LLMJSONExtractor.extractJSON(from: validatedText(data: data, httpResponse: httpResponse))

        do {
            return try JSONDecoder().decode(T.self, from: Data(text.utf8))
        } catch {
            // Last-ditch: the model may have stopped mid-object without a length
            // signal (a real truncation is thrown as `responseTruncated` before
            // reaching here). Try a conservative brace repair and decode once
            // more; the repaired form is used only if it decodes cleanly.
            if let repaired = LLMJSONExtractor.repairTruncatedJSON(text), repaired != text,
               let recovered = try? JSONDecoder().decode(T.self, from: Data(repaired.utf8)) {
                log(.info, "\(providerDisplayName) \(label): recovered truncated JSON via brace repair")
                return recovered
            }
            log(.error, "Failed to decode \(providerDisplayName) \(label) | \(LLMJSONExtractor.decodingErrorDetail(error)) | \(text.utf8.count) bytes")
            log(.debug, "\(providerDisplayName) \(label) raw response: \(text.prefix(500))")
            throw OpenAIError.invalidResponse
        }
    }

    public func extractPlainTextResponse(data: Data, httpResponse: HTTPURLResponse) throws -> String {
        try validatedText(data: data, httpResponse: httpResponse)
    }

    /// Map HTTP status and body error/refusal/truncation states to `OpenAIError`,
    /// returning the response text when it carries some.
    private func validatedText(data: Data, httpResponse: HTTPURLResponse) throws -> String {
        try throwForStatus(httpResponse, data: data, resetsRetiredModel: true)

        let text: String?
        let refusal: String?
        let isTruncated: Bool
        let isFiltered: Bool
        do {
            switch endpoint.wireFormat {
            case .chatCompletions:
                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                (text, refusal, isTruncated, isFiltered) = (response.extractedText, response.refusal, response.isTruncated, response.isFiltered)
            case .responses:
                let response = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
                (text, refusal, isTruncated, isFiltered) = (response.extractedText, response.refusal, response.isTruncated, response.isFiltered)
            }
        } catch {
            log(.error, "Failed to decode \(providerDisplayName) response: \(error.localizedDescription)")
            throw OpenAIError.invalidResponse
        }

        if let refusal {
            log(.warning, "\(providerDisplayName) refused the request: \(refusal)")
            throw OpenAIError.contentBlocked("refusal")
        }
        if isFiltered {
            log(.warning, "\(providerDisplayName) filtered the response")
            throw OpenAIError.contentBlocked("content_filter")
        }
        if isTruncated {
            log(.warning, "\(providerDisplayName) response truncated (output token limit)")
            throw OpenAIError.responseTruncated
        }
        guard let text, !text.isEmpty else {
            throw OpenAIError.invalidResponse
        }
        return text
    }

    /// Status mapping shared by generation and listing. Only a body that names
    /// the model as unknown counts as a retired model (a mistyped base URL also
    /// 404s, and must not reset the user's selection).
    private func throwForStatus(_ httpResponse: HTTPURLResponse, data: Data, resetsRetiredModel: Bool) throws {
        let status = httpResponse.statusCode
        guard !(200 ... 299).contains(status) else { return }
        let payload = OpenAIErrorBody.parse(data)
        let message = payload?.message ?? "HTTP \(status)"

        switch status {
        case 401, 403:
            log(.error, "\(providerDisplayName) API key rejected (HTTP \(status)): \(message)")
            throw OpenAIError.invalidAPIKey(provider: providerDisplayName)
        case 402:
            log(.error, "\(providerDisplayName) reports insufficient credit: \(message)")
            throw OpenAIError.insufficientQuota
        case 400, 404:
            if resetsRetiredModel, payload?.indicatesUnknownModel == true {
                let retired = modelStore.current.modelID
                modelStore.resetToFallback()
                log(.warning, "\(providerDisplayName) model '\(retired)' is unknown (HTTP \(status)); reset selection to \(configuration.fallbackModel.modelID)")
                throw OpenAIError.modelRetired(retired)
            }
            log(.error, "\(providerDisplayName) rejected the request (HTTP \(status)): \(message)")
            throw status == 400 ? OpenAIError.invalidRequest(message) : OpenAIError.serverError(status)
        case 413:
            log(.warning, "\(providerDisplayName) API request too large: \(message)")
            throw OpenAIError.requestTooLarge
        case 429:
            if payload?.indicatesInsufficientQuota == true {
                log(.error, "\(providerDisplayName) reports exhausted quota: \(message)")
                throw OpenAIError.insufficientQuota
            }
            log(.warning, "\(providerDisplayName) API rate limited")
            throw OpenAIError.rateLimited
        default:
            log(.error, "\(providerDisplayName) API server error (HTTP \(status)): \(message)")
            throw OpenAIError.serverError(status)
        }
    }

    // MARK: - Logging

    func log(_ level: SophonLogLevel, _ message: String) {
        configuration.logHandler(level, message)
    }
}
