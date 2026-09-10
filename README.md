# Sophon

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2018%2B%20%7C%20macOS%2015%2B%20%7C%20Mac%20Catalyst%2018%2B-blue.svg)](Package.swift)
[![Release](https://img.shields.io/github/v/release/Luminoid/Sophon)](https://github.com/Luminoid/Sophon/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Gemini client for Swift. Sophon is a Swift Package for iOS 18+, macOS 15+, and Mac Catalyst that wraps the Google Gemini API with schema-constrained structured output, configurable retry policies, a model catalog that falls back automatically when Google retires a model, and lenient decoding for the JSON that LLMs actually return. The request/retry/decoding kernel was extracted from three production iOS apps that each carried it as copy-pasted code, and it ships in all three today (see [Used in](#used-in)). Gemini is the only provider so far; further providers land as sibling targets on the same core.

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
    .package(url: "https://github.com/Luminoid/Sophon.git", from: "0.2.0"),
]
```

Sophon is listed on the [Swift Package Index](https://swiftpackageindex.com/Luminoid/Sophon), which hosts the DocC API reference for [SophonCore](https://swiftpackageindex.com/Luminoid/Sophon/documentation/sophoncore) and [SophonGemini](https://swiftpackageindex.com/Luminoid/Sophon/documentation/sophongemini).

## Usage

Each app defines one configuration and one shared client:

```swift
import SophonGemini

extension GeminiClientConfiguration {
    static let myApp = GeminiClientConfiguration(
        keychainAccount: "com.myapp.geminiAPIKey",
        defaultModel: .gemini38Flash,
        availableModels: [.gemini31FlashLite, .gemini31Pro, .gemini35FlashLite, .gemini38Flash],
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

Pick `defaultModel` and `fallbackModel` from models with a [Gemini API free tier](https://ai.google.dev/gemini-api/docs/pricing): end users supply their own API key, and the out-of-box experience should work on a free key with no billing enabled. Paid-only models (such as Gemini 3.1 Pro) fit `availableModels` as an explicit opt-in.

## Error copy

`GeminiError` descriptions resolve from the package's string catalog (en, es, zh-Hans, zh-Hant) with app-neutral wording. Apps that want feature-specific copy ("Gemini returned a trip we couldn't read") map the cases at their feature layer.

## Example App

The `Example/` directory contains a small catalog app exercising the package end to end: API key and model settings, schema-constrained structured output, multi-turn chat, and the offline JSON extractor (no API key needed). It uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```bash
cd Example
xcodegen generate
open SophonExample.xcodeproj
```

## Development

```bash
brew bundle      # install swiftlint + swiftformat + xcodegen
make setup-hooks # wire pre-commit lint + format
make check       # SwiftLint --strict + SwiftFormat --lint
make test        # xcodebuild, iOS simulator (canonical)
make test-host   # swift test (fast, Foundation-only surface)
```

## Used in

Sophon carries the Gemini integration in three App Store apps for iPhone, iPad, and Mac:

| App | What it is |
|-----|------------|
| [Plantfolio](https://apps.apple.com/us/app/plantfolio-plus/id6757148663) | Plant care: AI plant identification, seasonal watering schedules, collections ([site](https://plantfolio.luminoid.dev)) |
| [Petfolio](https://apps.apple.com/us/app/petfolio-pet-care/id6764127493) | Pet care: health logs, vet visits, medication schedules, Family Sharing ([site](https://petfolio.luminoid.dev)) |
| [TripDays](https://apps.apple.com/us/app/tripdays-trip-planner/id6794614173) | Collaborative travel planner: itineraries, paste-to-fill travel links, shared trips, expense splitting ([site](https://tripdays.luminoid.dev)) |

## License

MIT. © Luminoid. See [LICENSE](LICENSE) and [CHANGELOG](CHANGELOG.md).

## Related projects

- [Monolith](https://github.com/Luminoid/Monolith): CLI that scaffolds iOS apps, Swift Packages, and Swift CLIs (Sophon was scaffolded with it)
- Everything else at [luminoid.dev](https://luminoid.dev)
