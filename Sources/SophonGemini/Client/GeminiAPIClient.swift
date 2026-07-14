//
//  GeminiAPIClient.swift
//  SophonGemini
//
//  Networking layer for Gemini `generateContent` calls: request building,
//  policy-driven retry (backoff, Retry-After, 404 model fallback, image
//  downscale), structured/plain-text decoding, and truncated-JSON recovery.
//

import Foundation
import SophonCore

@MainActor
public final class GeminiAPIClient {
    public let configuration: GeminiClientConfiguration
    public let modelStore: GeminiModelStore
    private let session: URLSession

    /// Build a client from a configuration. Pass a custom `session` to add
    /// debug network logging or, in tests, a `URLProtocol` mock; nil builds one
    /// from the configuration's timeouts.
    public init(configuration: GeminiClientConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        modelStore = GeminiModelStore(configuration: configuration)
        if let session {
            self.session = session
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout
            sessionConfig.timeoutIntervalForResource = configuration.resourceTimeout
            self.session = URLSession(configuration: sessionConfig)
        }
    }

    // MARK: - API Key

    public func loadAPIKey() -> String? {
        configuration.loadAPIKey()
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
        let urlString = "\(configuration.apiBaseURL)\(resolvedModelID):generateContent"
        guard let url = URL(string: urlString) else {
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
        try await sendWithRetry(label: label, policy: retryPolicy ?? configuration.retryPolicy, buildRequest: buildRequest) { data, response in
            try self.decodeResponse(type, data: data, httpResponse: response, label: label)
        }
    }

    /// Send a multi-turn / plain-text request with the same retry behavior.
    public func sendPlainText(
        label: String,
        retryPolicy: GeminiRetryPolicy? = nil,
        buildRequest: (GeminiRequestVariant) async throws -> URLRequest
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
        parts: [GeminiPart] = [],
        schema: GeminiSchema? = nil,
        temperature: Double = 0.1,
        retryPolicy: GeminiRetryPolicy? = nil
    ) async throws -> T {
        guard let apiKey = loadAPIKey() else { throw GeminiError.apiKeyMissing }
        return try await send(type, label: label, retryPolicy: retryPolicy) { [self] variant in
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
        }
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
        guard let apiKey = loadAPIKey() else { throw GeminiError.apiKeyMissing }
        return try await sendPlainText(label: label, retryPolicy: retryPolicy) { [self] variant in
            var request = try makeBaseRequest(apiKey: apiKey, modelID: variant.modelID)
            let body = Self.multiTurnBody(
                contents: contents,
                responseSchema: nil,
                responseMimeType: "text/plain",
                temperature: temperature
            )
            request.httpBody = try await Self.encodeBody(body)
            return request
        }
    }

    private func sendWithRetry<R>(
        label: String,
        policy: GeminiRetryPolicy,
        buildRequest: (GeminiRequestVariant) async throws -> URLRequest,
        decode: (Data, HTTPURLResponse) throws -> R
    ) async throws -> R {
        var compressImages = false
        var modelID = modelStore.current.modelID
        var triedFallbackModel = false
        var transientRetries = 0

        while true {
            var lastResponse: HTTPURLResponse?
            do {
                let variant = GeminiRequestVariant(useCompressedImages: compressImages, modelID: modelID)
                let request = try await buildRequest(variant)
                let (data, response) = try await performRequest(request)
                lastResponse = response
                return try decode(data, response)
            } catch let error as GeminiError {
                // 404: the selected model is retired. Retry once against the configured fallback model.
                if policy.retriesWithFallbackModelOn404, error.isModelRetired, !triedFallbackModel,
                   configuration.fallbackModel.modelID != modelID {
                    triedFallbackModel = true
                    modelID = configuration.fallbackModel.modelID
                    log(.info, "Gemini \(label): retrying with fallback model \(modelID)")
                    continue
                }

                // Transient (429 / 5xx / timeout): exponential backoff, bounded retries.
                if error.isRetryable, transientRetries < policy.maxRetries {
                    transientRetries += 1
                    if policy.downscalesImagesOnRetry, error.shouldCompressImagesOnRetry {
                        compressImages = true
                    }
                    let retryAfter = lastResponse.flatMap { Self.retryAfterSeconds(from: $0, cap: policy.maxDelay) }
                    let delay = policy.backoffDelay(retry: transientRetries, retryAfter: retryAfter)
                    log(.info, "Gemini \(label): transient error, retry \(transientRetries)/\(policy.maxRetries) in \(String(format: "%.1f", delay))s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw error
            }
        }
    }

    /// Parse a numeric `Retry-After` header into a delay clamped to `cap`, or nil if absent/invalid.
    public static func retryAfterSeconds(from response: HTTPURLResponse, cap: TimeInterval) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces),
              let seconds = TimeInterval(raw), seconds >= 0 else {
            return nil
        }
        return min(seconds, cap)
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
            // Last-ditch: the JSON may be truncated. Try a conservative brace repair and decode
            // once more. We only use the repaired form if it decodes cleanly, so this never masks
            // a genuinely malformed response.
            if let repaired = LLMJSONExtractor.repairTruncatedJSON(text), repaired != text,
               let recovered = try? JSONDecoder().decode(T.self, from: Data(repaired.utf8)) {
                log(.info, "Gemini \(label): recovered truncated JSON via brace repair")
                return recovered
            }
            log(.error, "Failed to decode Gemini \(label) | \(LLMJSONExtractor.decodingErrorDetail(error)) | Raw: \(text.prefix(500))")
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
        case 401, 403:
            log(.error, "Gemini API key invalid (HTTP \(httpResponse.statusCode))")
            throw GeminiError.invalidAPIKey
        case 404:
            let retired = modelStore.current.modelID
            modelStore.resetToFallback()
            log(.warning, "Gemini model '\(retired)' returned 404 (retired); reset selection to \(configuration.fallbackModel.modelID)")
            throw GeminiError.modelRetired(retired)
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

    // MARK: - Logging

    func log(_ level: SophonLogLevel, _ message: String) {
        configuration.logHandler(level, message)
    }
}
