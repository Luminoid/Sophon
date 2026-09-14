# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - Unreleased

Sophon becomes a multi-provider client. Every Gemini-era spelling keeps compiling: the shared types moved to `SophonCore` and `SophonGemini` re-exports them under their old names (`GeminiSchema`, `GeminiPart`, `GeminiContent`, `GeminiRetryPolicy`, `GeminiRequestVariant`, `GeminiModelStore`).

### Added

- `SophonOpenAI`: one `OpenAICompatibleClient` for OpenAI's Responses API and the Chat Completions dialect every compatible provider implements, with catalogs and endpoint presets for OpenAI, Groq, Mistral, OpenRouter, DeepSeek, Qwen (Alibaba Model Studio), GLM (Zhipu / Z.ai), Kimi (Moonshot), and Doubao (Volcengine Ark). Qwen, GLM, and Kimi carry China and international endpoints. Structured output runs as strict `json_schema` where the provider enforces it and as `json_object` with the schema spelled out in the prompt elsewhere; the output-token field, auth header, and attribution headers are per-endpoint knobs. `listFreeModels()` on OpenRouter.
- `SophonAnthropic`: `AnthropicAPIClient` for the Messages API with `output_config` structured output, image and PDF blocks, `system` hoisting, optional `effort`, and 413 / 429 / 529 handling (a 413 retries once with smaller images).
- `SophonCore` kernel shared by every provider: `LLMSchema` (one schema, two dialects: Gemini `responseSchema` and strict JSON Schema), `LLMMessage` / `LLMPart` / `LLMRole` (still `Encodable` in the 0.1 JSON shape for consumers that serialize them directly), `LLMRetryPolicy` + `LLMRetryLoop`, `LLMModelPreset` / `LLMModelInfo` / `LLMModelStore` / `LLMCatalogAudit`, `LLMProviderConfiguration`, the cross-provider `LLMClient` protocol, and the UIKit-gated `LLMImageEncoder`.
- Catalog metadata on every preset (`info`): lifecycle with shutdown dates, free-tier membership, generation, release date, list pricing in the provider's currency, image-input and sampling-parameter support, context window. Every catalog exposes `recommendedDefault`, `recommendedFallback`, `current`, `currentFreeTier`, `currentWithImageInput`, and `current(minimumGeneration:)`, so an app that adopts them needs only a Sophon update when models move. `freeAccess` states how each provider can be used without paying.
- `listModels()` on every client (Gemini `GET /v1beta/models`, OpenAI-compatible `GET /models`, Anthropic `GET /v1/models`), plus an explicit-key overload.
- Localized error copy for the new targets (en, es, zh-Hans, zh-Hant); the OpenAI-compatible copy names the endpoint ("Groq API key not set").
- `SophonTestSupport` target with a host-keyed `LLMMockURLProtocol` for the provider test targets.

### Changed

- `GeminiClientConfiguration` defaults now let Sophon decide: `defaultModel: .recommendedDefault` (3.8 Flash), `fallbackModel: .recommendedFallback` (3.5 Flash-Lite), `availableModels: GeminiModel.current` (every non-deprecated preset). Apps that pass explicit values are unaffected.
- `GeminiModel` metadata is verified against Google's pages as of 2026-09-13: 3 Flash Preview and 3.1 Flash-Lite (shutdown 2027-05-07) are deprecated; the 2.5 family, 3.1 Pro, 3.5 Flash-Lite, and 3.5 through 3.8 Flash are current, all with a free tier except 3.1 Pro.
- System-role messages sent to Gemini are lifted into `system_instruction`.

### Fixed

- `resetToFallback()` with a `.custom` fallback now persists the custom model ID as well as the storage key.

### Tests

- 210 tests across the four test targets on the iOS simulator: schema dialects, the generic model store and retry loop, catalog audits for all eleven catalogs, request building and status mapping for every wire format, the retired-model gate that never resets a selection on a plain 404, and the Gemini source-compatibility guard.

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
