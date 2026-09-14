//
//  AnthropicAPIClient.swift
//  SophonAnthropic
//
//  Networking layer for Messages API calls: request building, policy-driven
//  retry via the shared `LLMRetryLoop` (backoff, Retry-After, overload,
//  retired-model fallback, image downscale), structured/plain-text decoding
//  with truncated-JSON recovery, and live model listing.
//

import Foundation
import SophonCore

@MainActor
public final class AnthropicAPIClient: LLMClient {
    public let configuration: AnthropicClientConfiguration
    public let modelStore: AnthropicModelStore
    private let session: URLSession

    /// Build a client from a configuration. Pass a custom `session` to add
    /// debug network logging or, in tests, a `URLProtocol` mock; nil builds one
    /// from the configuration's timeouts.
    public init(configuration: AnthropicClientConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        modelStore = configuration.modelStore
        if let session {
            self.session = session
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout
            sessionConfig.timeoutIntervalForResource = configuration.resourceTimeout
            self.session = URLSession(configuration: sessionConfig)
        }
    }

    public var providerDisplayName: String { "Claude" }

    public var currentModelID: String { modelStore.current.modelID }

    // MARK: - API Key

    public func loadAPIKey() -> String? {
        configuration.loadAPIKey()
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
        var request = try makeBaseRequest(apiKey: apiKey, path: "messages", method: "POST")
        let body = makeBody(contents: contents, modelID: modelID, responseSchema: responseSchema, temperature: temperature)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func makeBody(contents: [LLMMessage], modelID: String?, responseSchema: LLMSchema?, temperature: Double) -> AnthropicRequest {
        let resolvedModelID = modelID ?? modelStore.current.modelID
        let preset = AnthropicModel.allStandardCases.first { $0.modelID == resolvedModelID } ?? .custom(resolvedModelID)
        return AnthropicRequest.make(
            modelID: resolvedModelID,
            messages: contents,
            maxTokens: configuration.maxOutputTokens,
            temperature: preset.info.supportsTemperature ? temperature : nil,
            schema: responseSchema,
            effort: configuration.effort
        )
    }

    /// JSON-encode a request body off the calling executor. Multi-image bodies
    /// run to tens of megabytes of base64 text, and escaping them is measurable
    /// main-thread work.
    nonisolated static func encodeBody(_ body: AnthropicRequest) async throws -> Data {
        try await Task.detached { try JSONEncoder().encode(body) }.value
    }

    private func makeBaseRequest(apiKey: String, path: String, method: String) throws -> URLRequest {
        // The key rides in a header, never in the URL: NSURLError userInfo
        // embeds the failing URL verbatim, so a query-string key would leak
        // into every transport-error log.
        let urlString = configuration.apiBaseURL + path
        guard let url = URL(string: urlString), url.scheme != nil, url.host() != nil else {
            throw AnthropicError.invalidEndpoint(urlString)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(configuration.apiVersion, forHTTPHeaderField: "anthropic-version")
        return request
    }

    public func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log(.error, "Claude API request failed: \(error.localizedDescription)")
            throw AnthropicError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        return (data, httpResponse)
    }

    // MARK: - Retry-Aware Send

    /// Send a structured (JSON) request with automatic transient-error retry and model fallback.
    /// `buildRequest` is invoked once per attempt with the variant (image size + model ID) the
    /// retry loop wants for that attempt, so a retry can re-encode smaller images or swap models.
    /// Errors the closure throws that are not `AnthropicError` propagate as-is, without retry.
    public func send<T: Decodable>(
        _ type: T.Type,
        label: String,
        retryPolicy: LLMRetryPolicy? = nil,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest
    ) async throws -> T {
        try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, buildRequest: buildRequest) { data, response in
            try self.decodeResponse(type, data: data, httpResponse: response, label: label)
        }
    }

    /// Send a multi-turn / plain-text request with the same retry behavior.
    public func sendPlainText(
        label: String,
        retryPolicy: LLMRetryPolicy? = nil,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest
    ) async throws -> String {
        try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, buildRequest: buildRequest) { data, response in
            try self.extractPlainTextResponse(data: data, httpResponse: response)
        }
    }

    // MARK: - Conveniences

    /// One-call structured generation: prompt (+ optional media parts) in,
    /// decoded result out. Loads the API key itself and encodes the request body
    /// off-main; downscale-on-retry does not apply since the parts are pre-encoded.
    public func generateStructured<T: Decodable>(
        _ type: T.Type,
        label: String,
        prompt: String,
        parts: [LLMPart] = [],
        schema: LLMSchema? = nil,
        temperature: Double = 0.1,
        retryPolicy: LLMRetryPolicy? = nil
    ) async throws -> T {
        guard let apiKey = loadAPIKey() else { throw AnthropicError.apiKeyMissing }
        return try await send(type, label: label, retryPolicy: retryPolicy) { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, path: "messages", method: "POST")
            let body = makeBody(
                contents: [LLMMessage(parts: parts + [.text(prompt)], role: .user)],
                modelID: variant.modelID,
                responseSchema: schema,
                temperature: temperature
            )
            request.httpBody = try await Self.encodeBody(body)
            return request
        }
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
        guard let apiKey = loadAPIKey() else { throw AnthropicError.apiKeyMissing }
        return try await sendPlainText(label: label, retryPolicy: retryPolicy) { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, path: "messages", method: "POST")
            let body = makeBody(contents: contents, modelID: variant.modelID, responseSchema: nil, temperature: temperature)
            request.httpBody = try await Self.encodeBody(body)
            return request
        }
    }

    private func sendWithRetry<R>(
        label: String,
        policy: LLMRetryPolicy,
        buildRequest: (LLMRequestVariant) async throws -> URLRequest,
        decode: (Data, HTTPURLResponse) throws -> R
    ) async throws -> R {
        try await LLMRetryLoop.run(
            providerName: "Claude",
            label: label,
            policy: policy,
            initialModelID: modelStore.current.modelID,
            fallbackModelID: configuration.fallbackModel.modelID,
            log: { level, message in self.log(level, message) },
            buildRequest: buildRequest,
            perform: { request in try await self.performRequest(request) },
            decode: decode
        )
    }

    // MARK: - Model Listing

    /// The models the API serves right now (`GET /v1/models`). Pages through
    /// the listing; no retry.
    public func listModels() async throws -> [LLMRemoteModel] {
        guard let apiKey = loadAPIKey() else { throw AnthropicError.apiKeyMissing }
        return try await listModels(apiKey: apiKey)
    }

    /// `listModels()` with an explicit key, for callers that hold the key themselves.
    public func listModels(apiKey: String) async throws -> [LLMRemoteModel] {
        var models: [LLMRemoteModel] = []
        var afterID: String?
        var pagesFetched = 0
        repeat {
            var path = "models?limit=1000"
            if let afterID { path += "&after_id=\(afterID)" }
            let request = try makeBaseRequest(apiKey: apiKey, path: path, method: "GET")
            let (data, httpResponse) = try await performRequest(request)
            try throwForStatus(httpResponse, data: data, resetsRetiredModel: false)
            let page: AnthropicModelListResponse
            do {
                page = try JSONDecoder().decode(AnthropicModelListResponse.self, from: data)
            } catch {
                log(.error, "Failed to decode Claude model list: \(error.localizedDescription)")
                throw AnthropicError.invalidResponse
            }
            models += (page.data ?? []).map(\.remoteModel)
            afterID = page.hasMore == true ? page.lastID : nil
            pagesFetched += 1
        } while afterID != nil && pagesFetched < Self.maxListPages
        return models
    }

    private static let maxListPages = 10

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
            // Last-ditch: the JSON may be truncated. Try a conservative brace repair and decode
            // once more; the repaired form is used only if it decodes cleanly.
            if let repaired = LLMJSONExtractor.repairTruncatedJSON(text), repaired != text,
               let recovered = try? JSONDecoder().decode(T.self, from: Data(repaired.utf8)) {
                log(.info, "Claude \(label): recovered truncated JSON via brace repair")
                return recovered
            }
            log(.error, "Failed to decode Claude \(label) | \(LLMJSONExtractor.decodingErrorDetail(error)) | Raw: \(text.prefix(500))")
            throw AnthropicError.invalidResponse
        }
    }

    public func extractPlainTextResponse(data: Data, httpResponse: HTTPURLResponse) throws -> String {
        try validatedText(data: data, httpResponse: httpResponse)
    }

    /// Map HTTP status and body refusal/truncation states to `AnthropicError`,
    /// returning the response text when it carries some.
    private func validatedText(data: Data, httpResponse: HTTPURLResponse) throws -> String {
        try throwForStatus(httpResponse, data: data, resetsRetiredModel: true)

        let response: AnthropicResponse
        do {
            response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            log(.error, "Failed to decode Claude response: \(error.localizedDescription)")
            throw AnthropicError.invalidResponse
        }

        if response.isRefusal {
            log(.warning, "Claude refused the request")
            throw AnthropicError.contentBlocked("refusal")
        }
        if response.isTruncated {
            log(.warning, "Claude response truncated (max_tokens)")
            throw AnthropicError.responseTruncated
        }
        guard let text = response.extractedText, !text.isEmpty else {
            throw AnthropicError.invalidResponse
        }
        return text
    }

    /// Status mapping shared by generation and listing. Only a 404 whose body
    /// names the model counts as a retired model (a mistyped base URL also
    /// 404s, and must not reset the user's selection).
    private func throwForStatus(_ httpResponse: HTTPURLResponse, data: Data, resetsRetiredModel: Bool) throws {
        let status = httpResponse.statusCode
        guard !(200 ... 299).contains(status) else { return }
        let payload = AnthropicErrorBody.parse(data)
        let message = payload?.message ?? "HTTP \(status)"

        switch status {
        case 401, 403:
            log(.error, "Claude API key rejected (HTTP \(status)): \(message)")
            throw AnthropicError.invalidAPIKey
        case 404:
            if resetsRetiredModel, payload?.indicatesUnknownModel == true {
                let retired = modelStore.current.modelID
                modelStore.resetToFallback()
                log(.warning, "Claude model '\(retired)' returned 404 (retired); reset selection to \(configuration.fallbackModel.modelID)")
                throw AnthropicError.modelRetired(retired)
            }
            log(.error, "Claude API endpoint not found: \(message)")
            throw AnthropicError.serverError(404)
        case 400:
            log(.error, "Claude API rejected the request: \(message)")
            throw AnthropicError.invalidRequest(message)
        case 413:
            log(.warning, "Claude API request too large: \(message)")
            throw AnthropicError.requestTooLarge
        case 429:
            log(.warning, "Claude API rate limited")
            throw AnthropicError.rateLimited
        case 529:
            log(.warning, "Claude API overloaded")
            throw AnthropicError.overloaded
        default:
            log(.error, "Claude API server error (HTTP \(status)): \(message)")
            throw AnthropicError.serverError(status)
        }
    }

    // MARK: - Logging

    func log(_ level: SophonLogLevel, _ message: String) {
        configuration.logHandler(level, message)
    }
}
