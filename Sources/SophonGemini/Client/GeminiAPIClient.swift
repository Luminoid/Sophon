//
//  GeminiAPIClient.swift
//  SophonGemini
//
//  Networking layer for Gemini `generateContent` calls: request building,
//  policy-driven retry (backoff, Retry-After, 404 model fallback, image
//  downscale) via the shared `LLMRetryLoop`, structured/plain-text decoding
//  with brace repair for responses that end early without a truncation
//  signal, and live model listing.
//

import Foundation
import SophonCore

@MainActor
public final class GeminiAPIClient: LLMClient {
    public let configuration: GeminiClientConfiguration
    public let modelStore: GeminiModelStore
    private let session: URLSession
    private let ownsSession: Bool

    /// Build a client from a configuration. Pass a custom `session` to add
    /// debug network logging or, in tests, a `URLProtocol` mock; nil builds an
    /// ephemeral one from the configuration's timeouts (no shared URL cache or
    /// cookie jar, so a cached `GET /models` can never go stale on disk).
    public init(configuration: GeminiClientConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        modelStore = GeminiModelStore(configuration: configuration)
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

    public var providerDisplayName: String { "Gemini" }

    public var currentModelID: String { modelStore.current.modelID }

    // MARK: - API Key

    public func loadAPIKey() -> String? {
        configuration.loadAPIKey()
    }

    /// The stored key, or `apiKeyMissing` / `apiKeyInaccessible` (locked Keychain).
    private func requireAPIKey() throws -> String {
        try configuration.requireAPIKey(missing: { GeminiError.apiKeyMissing }, inaccessible: GeminiError.apiKeyInaccessible)
    }

    // MARK: - Request Building & Execution

    /// Build a single-turn `generateContent` request. Media parts (images, PDFs)
    /// go before the instruction text so the model reads the prompt in the
    /// context of the already-ingested documents. Body encoding runs on the
    /// caller's executor; the `generate*` conveniences encode off-main instead.
    public func buildRequest(
        parts: [GeminiPart] = [],
        promptText: String,
        apiKey: String,
        modelID: String? = nil,
        responseSchema: GeminiSchema? = nil,
        temperature: Double = 0.1,
        responseMimeType: String = "application/json"
    ) throws -> URLRequest {
        var request = try makeBaseRequest(apiKey: apiKey, modelID: modelID)
        let body = Self.singleTurnBody(
            parts: parts,
            promptText: promptText,
            responseSchema: responseSchema,
            temperature: temperature,
            responseMimeType: responseMimeType
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Build a multi-turn request from explicit role-tagged contents.
    public func buildMultiTurnRequest(
        contents: [GeminiContent],
        apiKey: String,
        modelID: String? = nil,
        responseSchema: GeminiSchema? = nil,
        responseMimeType: String = "text/plain",
        temperature: Double = 0.3
    ) throws -> URLRequest {
        var request = try makeBaseRequest(apiKey: apiKey, modelID: modelID)
        let body = Self.multiTurnBody(
            contents: contents,
            responseSchema: responseSchema,
            responseMimeType: responseMimeType,
            temperature: temperature
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private nonisolated static func singleTurnBody(
        parts: [GeminiPart],
        promptText: String,
        responseSchema: GeminiSchema?,
        temperature: Double,
        responseMimeType: String
    ) -> GeminiRequest {
        GeminiRequest(
            contents: [GeminiContent(parts: parts + [.text(promptText)])],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: responseMimeType,
                temperature: temperature,
                responseSchema: responseSchema
            )
        )
    }

    private nonisolated static func multiTurnBody(
        contents: [GeminiContent],
        responseSchema: GeminiSchema?,
        responseMimeType: String,
        temperature: Double
    ) -> GeminiRequest {
        GeminiRequest(
            contents: contents,
            generationConfig: GeminiGenerationConfig(
                responseMimeType: responseMimeType,
                temperature: temperature,
                responseSchema: responseSchema
            )
        )
    }

    /// JSON-encode a request body off the calling executor. Multi-image bodies
    /// run to tens of megabytes of base64 text, and escaping them is measurable
    /// main-thread work.
    nonisolated static func encodeBody(_ body: GeminiRequest) async throws -> Data {
        try await Task.detached { try JSONEncoder().encode(body) }.value
    }

    private func makeBaseRequest(apiKey: String, modelID: String?) throws -> URLRequest {
        // The key rides in a header, never in the URL: NSURLError userInfo
        // embeds the failing URL verbatim, so a query-string key would leak
        // into every transport-error log.
        let resolvedModelID = modelID ?? modelStore.current.modelID
        // Percent-encode the (possibly user-typed) ID so a stray `?` or `#`
        // fails the URL guard instead of silently becoming a query or fragment.
        guard let encodedModelID = resolvedModelID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              !encodedModelID.isEmpty,
              let url = URL(string: "\(configuration.apiBaseURL)\(encodedModelID):generateContent") else {
            throw GeminiError.invalidModelID(resolvedModelID)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        return request
    }

    public func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log(.error, "Gemini API request failed: \(error.localizedDescription)")
            throw GeminiError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        return (data, httpResponse)
    }

    // MARK: - Retry-Aware Send

    /// Send a structured (JSON) request with automatic transient-error retry and model fallback.
    /// `buildRequest` is invoked once per attempt with the variant (image size + model ID) the
    /// retry loop wants for that attempt, so a retry can re-encode smaller images or swap models.
    /// Errors the closure throws that are not `GeminiError` propagate as-is, without retry.
    public func send<T: Decodable>(
        _ type: T.Type,
        label: String,
        retryPolicy: GeminiRetryPolicy? = nil,
        buildRequest: (GeminiRequestVariant) async throws -> URLRequest
    ) async throws -> T {
        try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: true, buildRequest: buildRequest) { data, response in
            try self.decodeResponse(type, data: data, httpResponse: response, label: label)
        }
    }

    /// Send a multi-turn / plain-text request with the same retry behavior.
    public func sendPlainText(
        label: String,
        retryPolicy: GeminiRetryPolicy? = nil,
        buildRequest: (GeminiRequestVariant) async throws -> URLRequest
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
        parts: [GeminiPart] = [],
        schema: GeminiSchema? = nil,
        temperature: Double = 0.1,
        retryPolicy: GeminiRetryPolicy? = nil
    ) async throws -> T {
        let apiKey = try requireAPIKey()
        return try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: false, buildRequest: { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, modelID: variant.modelID)
            let body = Self.singleTurnBody(
                parts: parts,
                promptText: prompt,
                responseSchema: schema,
                temperature: temperature,
                responseMimeType: "application/json"
            )
            request.httpBody = try await Self.encodeBody(body)
            return request
        }, decode: { data, response in
            try self.decodeResponse(type, data: data, httpResponse: response, label: label)
        })
    }

    /// One-call plain-text generation over explicit role-tagged contents
    /// (multi-turn conversations, free-form reports). Encodes the request body
    /// off-main.
    public func generateText(
        label: String,
        contents: [GeminiContent],
        temperature: Double = 0.3,
        retryPolicy: GeminiRetryPolicy? = nil
    ) async throws -> String {
        let apiKey = try requireAPIKey()
        return try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, canDownscaleImages: false, buildRequest: { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, modelID: variant.modelID)
            let body = Self.multiTurnBody(
                contents: contents,
                responseSchema: nil,
                responseMimeType: "text/plain",
                temperature: temperature
            )
            request.httpBody = try await Self.encodeBody(body)
            return request
        }, decode: { data, response in
            try self.extractPlainTextResponse(data: data, httpResponse: response)
        })
    }

    private func sendWithRetry<R>(
        label: String,
        policy: GeminiRetryPolicy,
        canDownscaleImages: Bool,
        buildRequest: (GeminiRequestVariant) async throws -> URLRequest,
        decode: (Data, HTTPURLResponse) throws -> R
    ) async throws -> R {
        try await LLMRetryLoop.run(
            providerName: "Gemini",
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

    /// The generation models the API serves right now (`GET /v1beta/models`,
    /// filtered to `generateContent`). Pages through the listing; no retry.
    public func listModels() async throws -> [LLMRemoteModel] {
        try await listModels(apiKey: requireAPIKey())
    }

    /// `listModels()` with an explicit key, for callers that hold the key themselves.
    public func listModels(apiKey: String) async throws -> [LLMRemoteModel] {
        var models: [LLMRemoteModel] = []
        var pageToken: String?
        var pagesFetched = 0
        repeat {
            let request = try makeListRequest(apiKey: apiKey, pageToken: pageToken)
            let (data, httpResponse) = try await performRequest(request)
            try throwForListStatus(httpResponse, data: data)
            let page: GeminiModelListResponse
            do {
                page = try JSONDecoder().decode(GeminiModelListResponse.self, from: data)
            } catch {
                log(.error, "Failed to decode Gemini model list: \(error.localizedDescription)")
                throw GeminiError.invalidResponse
            }
            models += (page.models ?? []).filter(\.isGenerationModel).map(\.remoteModel)
            pageToken = page.nextPageToken
            pagesFetched += 1
        } while pageToken != nil && pagesFetched < Self.maxListPages
        return models
    }

    private static let maxListPages = 10

    private func makeListRequest(apiKey: String, pageToken: String?) throws -> URLRequest {
        // The configuration keeps exactly one trailing slash; the collection URL has none.
        let base = String(configuration.apiBaseURL.dropLast())
        guard var components = URLComponents(string: base) else {
            throw GeminiError.invalidResponse
        }
        var items = [URLQueryItem(name: "pageSize", value: "200")]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        components.queryItems = items
        guard let url = components.url else { throw GeminiError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        return request
    }

    private func throwForListStatus(_ httpResponse: HTTPURLResponse, data: Data) throws {
        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 400:
            throw GeminiError.invalidRequest(Self.apiErrorMessage(in: data) ?? "HTTP 400")
        case 401, 403:
            throw GeminiError.invalidAPIKey
        case 429:
            throw GeminiError.rateLimited
        default:
            throw GeminiError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Response Parsing

    public func decodeResponse<T: Decodable>(
        _ type: T.Type,
        data: Data,
        httpResponse: HTTPURLResponse,
        label: String
    ) throws -> T {
        let text = try extractResponseText(data: data, httpResponse: httpResponse)

        do {
            let jsonData = Data(text.utf8)
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            // Last-ditch: the model may have stopped mid-object without a
            // MAX_TOKENS signal (a real truncation is thrown as
            // `responseTruncated` before reaching here). Try a conservative brace
            // repair and decode once more; the repaired form is used only if it
            // decodes cleanly, so this never masks a genuinely malformed response.
            if let repaired = LLMJSONExtractor.repairTruncatedJSON(text), repaired != text,
               let recovered = try? JSONDecoder().decode(T.self, from: Data(repaired.utf8)) {
                log(.info, "Gemini \(label): recovered truncated JSON via brace repair")
                return recovered
            }
            log(.error, "Failed to decode Gemini \(label) | \(LLMJSONExtractor.decodingErrorDetail(error)) | \(text.utf8.count) bytes")
            log(.debug, "Gemini \(label) raw response: \(text.prefix(500))")
            throw GeminiError.invalidResponse
        }
    }

    public func extractPlainTextResponse(data: Data, httpResponse: HTTPURLResponse) throws -> String {
        let geminiResponse = try validatedResponse(data: data, httpResponse: httpResponse)
        guard let text = geminiResponse.extractedText, !text.isEmpty else {
            throw GeminiError.invalidResponse
        }
        return text
    }

    private func extractResponseText(data: Data, httpResponse: HTTPURLResponse) throws -> String {
        let geminiResponse = try validatedResponse(data: data, httpResponse: httpResponse)
        guard let text = geminiResponse.extractedText, !text.isEmpty else {
            throw GeminiError.invalidResponse
        }
        return LLMJSONExtractor.extractJSON(from: text)
    }

    /// Map HTTP status and response-body error/block/truncation states to
    /// `GeminiError`, returning the decoded response when it carries usable text.
    private func validatedResponse(data: Data, httpResponse: HTTPURLResponse) throws -> GeminiResponse {
        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 400:
            let message = Self.apiErrorMessage(in: data) ?? "HTTP 400"
            log(.error, "Gemini API rejected the request: \(message)")
            throw GeminiError.invalidRequest(message)
        case 401, 403:
            log(.error, "Gemini API key invalid (HTTP \(httpResponse.statusCode))")
            throw GeminiError.invalidAPIKey
        case 404:
            let retired = modelStore.current.modelID
            modelStore.resetToFallback()
            log(.warning, "Gemini model '\(retired)' returned 404 (retired); reset selection to \(configuration.fallbackModel.modelID)")
            throw GeminiError.modelRetired(retired)
        case 413:
            log(.warning, "Gemini API request too large")
            throw GeminiError.requestTooLarge
        case 429:
            log(.warning, "Gemini API rate limited")
            throw GeminiError.rateLimited
        default:
            log(.error, "Gemini API server error (HTTP \(httpResponse.statusCode))")
            throw GeminiError.serverError(httpResponse.statusCode)
        }

        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            log(.error, "Failed to decode Gemini response: \(error.localizedDescription)")
            throw GeminiError.invalidResponse
        }

        if let apiError = geminiResponse.error {
            log(.error, "Gemini API error: \(apiError.message ?? "unknown")")
            throw GeminiError.serverError(apiError.code ?? 500)
        }
        if let blockReason = geminiResponse.blockReason {
            log(.warning, "Gemini response blocked: \(blockReason)")
            throw GeminiError.contentBlocked(blockReason)
        }
        if geminiResponse.isTruncated {
            log(.warning, "Gemini response truncated (MAX_TOKENS)")
            throw GeminiError.responseTruncated
        }

        return geminiResponse
    }

    /// The `error.message` of an error body, if the body is one.
    private nonisolated static func apiErrorMessage(in data: Data) -> String? {
        (try? JSONDecoder().decode(GeminiResponse.self, from: data))?.error?.message
    }

    // MARK: - Logging

    func log(_ level: SophonLogLevel, _ message: String) {
        configuration.logHandler(level, message)
    }
}
