# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

Initial release: a shared Gemini kernel extracted from three production iOS apps that previously each carried it as copy-pasted code.

### Added

- `SophonCore`: `LLMDecoding` lenient decoders, `LLMJSONExtractor` (markdown-fence stripping, outermost-brace extraction, truncated-JSON repair, decoding-error formatting), `SophonKeychain` (account-parameterized), `SophonLogger` pluggable log handler (os.Logger default).
- `SophonGemini`: `GeminiAPIClient` (per-attempt request variants, Retry-After honoring, jitter, same-call 404 model fallback, truncated-JSON recovery, multi-turn, injectable URLSession), `GeminiClientConfiguration` (per-app keychain account, defaults keys, catalog, timeouts, retry policy, log handler), `GeminiRetryPolicy` with `.default` and `.minimal` presets plus per-call override, `generateStructured` / `generateText` conveniences, union `GeminiModel` catalog with successor-map resolution in `GeminiModelStore`, unified `GeminiError`, availability/masked-key helpers, UIKit-gated image encoding.
- Localized error copy (en, es, zh-Hans, zh-Hant) resolved from the package bundle. Shipped as classic `.lproj/Localizable.strings`: command-line SwiftPM copies `.xcstrings` raw without compiling, which breaks `String(localized:bundle:)` under `swift test`.
- 103 tests: client and decoding behavior, both retry-policy presets, model-store resolution matrix, media-before-text part ordering, `propertyOrdering` schema encoding, string-catalog resolution lock.
- Example app (`Example/`, XcodeGen-generated): API key and model settings, schema-constrained structured output, multi-turn chat, and the offline JSON extractor.

### Migration notes for consuming apps

- Keychain accounts and `ai.*` UserDefaults keys are preserved via configuration; users' stored API keys and model selections survive unchanged.
- Apps replacing a simpler hand-rolled client can adopt `.minimal` to keep fixed-backoff retry semantics, or `.default` for the richer loop. Regardless of policy, MAX_TOKENS responses surface as `responseTruncated` and safety blocks as `contentBlocked`, which may be more specific than whatever generic error a previous client mapped them to.
- Error copy is app-neutral package-wide; feature-specific wording should be mapped at the feature layer if wanted.
