# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Sophon becomes a multi-provider client. Every Gemini-era spelling keeps compiling: the shared types moved to `SophonCore` and `SophonGemini` re-exports them under their old names (`GeminiSchema`, `GeminiPart`, `GeminiContent`, `GeminiRetryPolicy`, `GeminiRequestVariant`, `GeminiModelStore`, all in `GeminiCompatibility.swift`).

### Added

- `SophonOpenAI`: one `OpenAICompatibleClient` for OpenAI's Responses API and the Chat Completions dialect every compatible provider implements, with catalogs and endpoint presets for OpenAI, Groq, Mistral, OpenRouter, DeepSeek, Qwen (Alibaba Model Studio), GLM (Zhipu / Z.ai), Kimi (Moonshot), and Doubao (Volcengine Ark). Qwen, GLM, and Kimi carry China and international endpoints. Structured output runs as strict `json_schema` where the provider enforces it and as `json_object` with the schema spelled out in the prompt elsewhere; the output-token field, auth header, and attribution headers are per-endpoint knobs (exercised by a custom-endpoint test). `listFreeModels()` on OpenRouter.
- `SophonAnthropic`: `AnthropicAPIClient` for the Messages API with `output_config` structured output, image and PDF blocks (plain-text documents go as text sources), `system` hoisting, optional `effort`, and 413 / 429 / 529 handling; an exhausted credit balance surfaces as `insufficientQuota`.
- `SophonCore` kernel shared by every provider: `LLMSchema` (one schema, two dialects: Gemini `responseSchema` and strict JSON Schema), `LLMMessage` / `LLMPart` / `LLMRole` (still `Encodable` in the 0.1 JSON shape for consumers that serialize them directly), `LLMRetryPolicy` + `LLMRetryLoop` + `LLMHTTP`, `LLMModelPreset` / `LLMModelInfo` / `LLMModelStore` / `LLMCatalogAudit`, `LLMProviderConfiguration`, the cross-provider `LLMClient` protocol, `LLMErrorCopy` with SophonCore's own string bundle, and the UIKit-gated `LLMImageEncoder`.
- Catalog metadata on every preset (`info`): lifecycle with shutdown dates, free-tier membership, generation, release date, list pricing in the provider's currency, image-input and sampling-parameter support, context window. Every catalog exposes `recommendedDefault`, `recommendedFallback`, `current`, `currentFreeTier`, `currentWithImageInput`, `current(minimumGeneration:)`, and `keyHintURL`, so an app that adopts them needs only a Sophon update when models move. `freeAccess` states how each provider can be used without paying.
- `listModels()` on every client (Gemini `GET /v1beta/models`, OpenAI-compatible `GET /models`, Anthropic `GET /v1/models`), plus an explicit-key overload.
- `apiKeyStatus()` / `requireAPIKey` on every configuration and an `apiKeyInaccessible` case on every error enum: a Keychain that refuses the read (device locked, `errSecInteractionNotAllowed`) is no longer reported as "API key not set". `SophonKeychain.read(account:)` throws `loadFailed`; `delete` reports whether the item is gone.
- `GeminiError.invalidRequest` (HTTP 400 with the API's message) and `requestTooLarge` (HTTP 413) on the Gemini and OpenAI-compatible clients, matching Claude's.
- `Retry-After` in HTTP-date form is honored alongside the delay-seconds form.
- Localized error copy for the new targets (en, es, zh-Hans, zh-Hant); the OpenAI-compatible copy names the endpoint ("Groq API key not set"). The cases every provider shares live once in `SophonCore`; each provider target carries only its provider-flavored lines.
- `SophonTestSupport` target with a host-keyed `LLMMockURLProtocol` and isolated-defaults factories, used by all three provider test targets.
- Example app rebuilt as a provider-switching catalog: a picker for all fourteen endpoints, per-provider key and model settings with catalog metadata and live model listing (OpenRouter lists its free roster), structured output and chat through `any LLMClient`, keyboard and pointer support.
- `.spi.yml` documentation targets for all four products with DocC landing pages, a GitHub Actions workflow running the lint, strict-build, and test gates, and `make build-strict`.

### Changed

- `GeminiClientConfiguration` defaults now let Sophon decide: `defaultModel: .recommendedDefault` (3.8 Flash), `fallbackModel: .recommendedFallback` (3.5 Flash-Lite), `availableModels: GeminiModel.current` (every non-deprecated preset). Apps that pass explicit values are unaffected.
- `GeminiModel` metadata is verified against Google's pages as of 2026-09-13: 3 Flash Preview and 3.1 Flash-Lite (shutdown 2027-05-07) are deprecated; the 2.5 family, 3.1 Pro, 3.5 Flash-Lite, and 3.5 through 3.8 Flash are current, all with a free tier except 3.1 Pro.
- System-role messages sent to Gemini are lifted into `system_instruction`. On the OpenAI-compatible and Claude wires, media parts in a system message are dropped with a warning (those formats carry system text only), and messages with no parts are skipped.
- `LLMModelStore.current` never returns a preset outside `availableModels`: a default or fallback outside the roster resolves to the first offered preset.
- `SophonKeychain.save` updates an existing item in place instead of delete-then-add; reads and deletes match synchronizable items too. `saveAPIKey` trims the value and throws `emptyValue` when nothing is left.
- Clients build ephemeral `URLSession`s (no shared URL cache or cookie jar) and invalidate the ones they own on deinit.
- `LLMRetryPolicy` sanitizes negative or non-finite delays and a zero attempt count; the retry loop checks cancellation before every attempt.
- `LLMImageEncoder` encodes at most four images at a time and treats a negative `maxImages` as zero; the per-request cap and its warning live once in Core.
- The default log handler logs `.debug` privately; the raw model output echoed on a decode failure moves from the `.error` line to a `.debug` line.
- Gemini and Claude base URLs are normalized to exactly one trailing slash; Gemini percent-encodes the model ID; Claude's model listing builds its query with `URLComponents`.
- OpenAI-compatible unknown-model detection no longer matches a bare "not found", and Claude's matches `not_found_error` only, so a gateway's 404 body cannot reset the user's selection.
- `LLMModelInfo.day` traps on an impossible catalog date instead of silently producing a date in the distant past.
- `OpenAIEndpoint.keyPrefix` documents that region variants share it on purpose and therefore need distinct `keychainAccount`s.

### Removed

- The ten `is<Provider>Available` aliases (`isGroqAvailable`, `isAnthropicAvailable`, ...): use `isAvailable`. `isGeminiAvailable` stays for 0.1 / 0.2 source compatibility.
- `GeminiAPIClient.retryAfterSeconds(from:cap:)`: use `LLMHTTP.retryAfterSeconds(from:cap:)`.

### Fixed

- `resetToFallback()` with a `.custom` fallback now persists the custom model ID as well as the storage key.
- An oversized request (HTTP 413) is retried only when the request builder can re-encode the images smaller, and only once. The `generate*` conveniences take pre-encoded parts, so they fail at once instead of re-sending the identical body under the policy's attempt budget.
- `.jsonObject` mode fails the request when the schema cannot be rendered into the prompt instead of prompting with `{}`.

### Tests

- 235 tests across the four test targets on the iOS simulator (as the runner counts them, parameterized cases included): schema dialects, the generic model store (roster membership included) and retry loop (size-only retries, cancellation), Retry-After parsing in both forms, policy sanitizing, the shared error copy, catalog audits for all eleven catalogs plus key-prefix uniqueness, request building and status mapping for every wire format, custom endpoint knobs, the retired-model gate that never resets a selection on a plain 404, the 413 path on every client, and the Gemini source-compatibility guard.

## [0.2.0] - 2026-09-06

### Added

- `GeminiModel` presets for Gemini 3.5 Flash-Lite, 3.6 Flash, 3.7 Flash, and 3.8 Flash (all free-tier). Stored 3 Flash Preview selections resolve to 3.6 Flash and 3.1 Flash-Lite to 3.5 Flash-Lite.

### Fixed

- `LLMDecoding.int` no longer traps on out-of-range values; non-finite doubles are rejected and confidence is clamped to 0...1.

## [0.1.0] - 2026-07-14

Initial release: a shared Gemini kernel extracted from three production iOS apps that previously each carried it as copy-pasted code.

### Added

- `SophonCore`: `LLMDecoding` lenient decoders, `LLMJSONExtractor` (markdown-fence stripping, outermost-brace extraction, truncated-JSON repair, decoding-error formatting), `SophonKeychain` (account-parameterized), `SophonLogger` pluggable log handler (os.Logger default).
- `SophonGemini`: `GeminiAPIClient` (per-attempt request variants, Retry-After honoring, jitter, same-call 404 model fallback, truncated-JSON recovery, multi-turn, injectable URLSession), `GeminiClientConfiguration` (per-app keychain account, defaults keys, catalog, timeouts, retry policy, log handler), `GeminiRetryPolicy` with `.default` and `.minimal` presets plus per-call override, `generateStructured` / `generateText` conveniences, union `GeminiModel` catalog with successor-map resolution in `GeminiModelStore`, unified `GeminiError`, availability/masked-key helpers, UIKit-gated image encoding.
- Localized error copy (en, es, zh-Hans, zh-Hant) resolved from the package bundle. Shipped as classic `.lproj/Localizable.strings`: command-line SwiftPM copies `.xcstrings` raw without compiling, which breaks `String(localized:bundle:)` under `swift test`.
- 110 tests: client and decoding behavior, both retry-policy presets, model-store resolution matrix, media-before-text part ordering, `propertyOrdering` schema encoding, image-encoder pixel cap and ordering, string-catalog resolution lock.
- Example app (`Example/`, XcodeGen-generated): API key and model settings, schema-constrained structured output, multi-turn chat, and the offline JSON extractor.
