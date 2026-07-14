# Sophon

Shared AI infrastructure for Swift apps. v0.1.x speaks one provider, Google Gemini, and packages a request/retry/decoding kernel extracted from three production iOS apps that previously each carried it as copy-pasted code.

> 智子, the proton-sized intelligence from *The Three-Body Problem*: it observes and reports.

## Targets

| Product | Depends on | Contents |
|---------|-----------|----------|
| `SophonCore` | nothing | `LLMDecoding` (lenient LLM JSON decoding), `LLMJSONExtractor` (fence stripping, brace extraction, truncation repair), `SophonKeychain`, `SophonLogger` (pluggable log handler) |
| `SophonGemini` | `SophonCore` | `GeminiAPIClient`, `GeminiClientConfiguration`, `GeminiRetryPolicy`, request/response DTOs, `GeminiSchema` (structured output), `GeminiModel` catalog + `GeminiModelStore`, `GeminiError`, availability/key helpers, UIKit-gated image encoding |

Platforms: iOS 18+, Mac Catalyst 18+, macOS 15+ (Foundation surface only; image encoding is `#if canImport(UIKit)`).

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Luminoid/Sophon.git", from: "0.1.0"),
]
```

## Usage

Each app defines one configuration and one shared client:

```swift
import SophonGemini

extension GeminiClientConfiguration {
    static let myApp = GeminiClientConfiguration(
        keychainAccount: "com.myapp.geminiAPIKey",
        defaultModel: .gemini35Flash,
        availableModels: [.gemini31FlashLite, .gemini31Pro, .gemini35Flash],
        retryPolicy: .default,
        logHandler: { level, message in MyLogger.log(level, message) }
    )
}

extension GeminiAPIClient {
    static let shared = GeminiAPIClient(configuration: .myApp)
}
```

One-call structured generation (the common case):

```swift
struct Extraction: Decodable { let title: String }

let result = try await GeminiAPIClient.shared.generateStructured(
    Extraction.self,
    label: "extract",
    prompt: promptText,
    schema: .object(properties: ["title": .string()], required: ["title"])
)
```

Multi-turn plain text:

```swift
let reply = try await GeminiAPIClient.shared.generateText(
    label: "followUp",
    contents: conversationContents
)
```

Image-heavy flows use the closure-based `send` so retries can re-encode smaller images and swap models:

```swift
let result = try await client.send(MyResult.self, label: "identify") { variant in
    let parts = try await client.encodeImages(images, variant: variant)
    return try client.buildRequest(parts: parts, promptText: prompt, apiKey: apiKey, modelID: variant.modelID, responseSchema: schema)
}
```

## Retry policies

Retry behavior is a parameter, not a baked-in default. Set it per app in the configuration, or override per call.

| | `.default` | `.minimal` |
|---|---|---|
| Attempts | 3 | 3 |
| Backoff | 0.8s base, 6s cap, deterministic jitter | 1s base, fixed exponential |
| `Retry-After` header | honored (clamped) | ignored |
| 404 (retired model) | retries the call on the fallback model | fails the call |
| Transport failure | re-encodes images smaller | no re-encode |

Either way, a 404 persists a reset of the stored model selection to `fallbackModel`, so the user's next call succeeds.

## Model catalog

`GeminiModel` carries the full preset catalog; `availableModels` scopes what an app offers. A stored selection outside the app's catalog walks `GeminiModel.successor` (Google's documented replacements) and only then falls back, so pruning presets never strands a user's stored choice. `.custom(id)` always passes through.

## Error copy

`GeminiError` descriptions resolve from the package's string catalog (en, es, zh-Hans, zh-Hant) with app-neutral wording. Apps that want feature-specific copy ("Gemini returned a trip we couldn't read") map the cases at their feature layer.

## Development

```bash
brew bundle      # install swiftlint + swiftformat
make setup-hooks # wire pre-commit lint + format
make check       # SwiftLint --strict + SwiftFormat --lint
make test        # xcodebuild, iOS simulator (canonical)
make test-host   # swift test (fast, Foundation-only surface)
```

## License

MIT. © Luminoid. See [LICENSE](LICENSE) and [CHANGELOG](CHANGELOG.md).

Scaffolded with [Monolith](https://github.com/Luminoid/Monolith).
