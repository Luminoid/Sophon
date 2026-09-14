# Sophon

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2018%2B%20%7C%20macOS%2015%2B%20%7C%20Mac%20Catalyst%2018%2B-blue.svg)](Package.swift)
[![Release](https://img.shields.io/github/v/release/Luminoid/Sophon)](https://github.com/Luminoid/Sophon/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

LLM client for Swift. Sophon is a Swift Package for iOS 18+, macOS 15+, and Mac Catalyst that talks to Google Gemini, OpenAI and every OpenAI-compatible endpoint (Groq, Mistral, OpenRouter, DeepSeek, Qwen, GLM, Kimi, Doubao), and Anthropic's Claude through one kernel: schema-constrained structured output written once and encoded in each provider's dialect, configurable retry policies, model catalogs that carry lifecycle and free-tier metadata and fall back automatically when a provider retires a model, live model listing, and lenient decoding for the JSON that LLMs actually return. The request/retry/decoding kernel was extracted from three production iOS apps that each carried it as copy-pasted code, and it ships in all three today (see [Used in](#used-in)).

> 智子, the proton-sized intelligence from *The Three-Body Problem*: it observes and reports.

## Targets

| Product | Depends on | Contents |
|---------|-----------|----------|
| `SophonCore` | nothing | `LLMSchema` (one schema, two dialects), `LLMMessage` / `LLMPart`, `LLMRetryPolicy` + `LLMRetryLoop`, `LLMModelPreset` / `LLMModelInfo` / `LLMModelStore` / `LLMCatalogAudit`, `LLMProviderConfiguration` (key + availability helpers), the `LLMClient` protocol, `LLMDecoding` (lenient LLM JSON decoding), `LLMJSONExtractor` (fence stripping, brace extraction, truncation repair), `SophonKeychain`, `SophonLogger`, UIKit-gated `LLMImageEncoder` |
| `SophonGemini` | `SophonCore` | `GeminiAPIClient`, `GeminiClientConfiguration`, `GeminiModel` catalog, `GeminiError`, Gemini request/response DTOs |
| `SophonOpenAI` | `SophonCore` | `OpenAICompatibleClient` (Responses API and Chat Completions), `OpenAIEndpoint`, `OpenAIError`, catalogs + endpoint presets for OpenAI, Groq, Mistral, OpenRouter, DeepSeek, Qwen, GLM, Kimi, Doubao |
| `SophonAnthropic` | `SophonCore` | `AnthropicAPIClient`, `AnthropicClientConfiguration`, `AnthropicModel` catalog, `AnthropicError`, Messages API DTOs |

Platforms: iOS 18+, Mac Catalyst 18+, macOS 15+ (Foundation surface only; image encoding is `#if canImport(UIKit)`).

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Luminoid/Sophon.git", from: "0.3.0"),
]
```

Sophon is listed on the [Swift Package Index](https://swiftpackageindex.com/Luminoid/Sophon), which hosts the DocC API reference for [SophonCore](https://swiftpackageindex.com/Luminoid/Sophon/documentation/sophoncore), [SophonGemini](https://swiftpackageindex.com/Luminoid/Sophon/documentation/sophongemini), [SophonOpenAI](https://swiftpackageindex.com/Luminoid/Sophon/documentation/sophonopenai), and [SophonAnthropic](https://swiftpackageindex.com/Luminoid/Sophon/documentation/sophonanthropic).

## Usage

Each app defines one configuration and one shared client per provider it ships. Only the Keychain account is required; Sophon supplies the model defaults (see [Letting Sophon choose models](#letting-sophon-choose-models)).

```swift
import SophonGemini

extension GeminiClientConfiguration {
    static let myApp = GeminiClientConfiguration(
        keychainAccount: "com.myapp.geminiAPIKey",
        logHandler: { level, message in MyLogger.log(level, message) }
    )
}

extension GeminiAPIClient {
    static let shared = GeminiAPIClient(configuration: .myApp)
}
```

OpenAI-compatible providers share one client type; the catalog picks the endpoint, and providers with a China split take a region:

```swift
import SophonOpenAI

extension DeepSeekClientConfiguration {
    static let myApp = DeepSeekClientConfiguration(keychainAccount: "com.myapp.deepSeekAPIKey")
}

extension QwenClientConfiguration {
    static let myApp = QwenClientConfiguration(
        keychainAccount: "com.myapp.qwenAPIKey",
        endpoint: QwenModel.endpoint(region: .china)
    )
}

let deepSeek = DeepSeekAPIClient(configuration: .myApp)
let qwen = QwenAPIClient(configuration: .myApp)
```

Claude:

```swift
import SophonAnthropic

let claude = AnthropicAPIClient(configuration: AnthropicClientConfiguration(keychainAccount: "com.myapp.anthropicAPIKey"))
```

One-call structured generation is the same call on every client. The schema is written once; each client encodes it in its provider's dialect (Gemini `responseSchema`, OpenAI strict `json_schema` or `json_object`, Anthropic `output_config`):

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
let reply = try await claude.generateText(
    label: "followUp",
    contents: [
        LLMMessage(parts: [.text("You are a botanist.")], role: .system),
        LLMMessage(parts: [.text("Is my monstera overwatered?")], role: .user),
    ]
)
```

Image-heavy flows use the closure-based `send` so retries can re-encode smaller images and swap models:

```swift
let result = try await client.send(MyResult.self, label: "identify") { variant in
    let parts = try await client.encodeImages(images, variant: variant)
    return try client.buildRequest(parts: parts, promptText: prompt, apiKey: apiKey, modelID: variant.modelID, responseSchema: schema)
}
```

Apps that let users pick a provider hold `any LLMClient`; it covers `generateStructured`, `generateText`, `listModels()`, and the current model ID.

## Letting Sophon choose models

Every catalog carries metadata (`info`: lifecycle with shutdown dates, free-tier membership, generation, pricing, image input, sampling support) and three adoption helpers, so an app can decide once how much to delegate:

```swift
// Explicit presets: the app owns the roster and updates it by hand.
availableModels: [.gemini36Flash, .gemini37Flash, .gemini38Flash]

// Every non-deprecated preset: a Sophon update adds new models and drops retired ones.
availableModels: GeminiModel.current

// Narrower rosters: by generation, free tier, or image support.
availableModels: GeminiModel.current(minimumGeneration: 3)
availableModels: GLMModel.currentFreeTier
availableModels: OpenAIModel.currentWithImageInput

// Omitted: Sophon's recommended default and fallback plus `current`.
defaultModel: .recommendedDefault
fallbackModel: .recommendedFallback
```

A stored selection outside the app's roster walks the catalog's `successor` chain (the provider's documented replacements) and only then falls back, so pruning presets never strands a user's stored choice. `.custom(id)` always passes through, and `listModels()` returns what the provider serves right now for pickers that want the live roster (`listFreeModels()` on OpenRouter). `LLMCatalogAudit.violations(in:)` checks a catalog's invariants; every Sophon catalog passes it in tests.

Recommended defaults today: Gemini 3.8 Flash (fallback 3.5 Flash-Lite), GPT-5.6 Luna (GPT-5.4 mini), Claude Sonnet 5 (Haiku 4.5), Groq gpt-oss-120b, Mistral Small 4, DeepSeek V4.1 Flash, Qwen Flash, GLM-4.7 Flash, Kimi K2.6, Doubao Seed 2.1 Turbo. Where a provider has a permanent free tier, the recommended pair is on it.

## Free access

Users bring their own API key, so the out-of-box experience matters. As of 2026-09-13 (each catalog's `freeAccess` carries the same facts):

| Provider | Free access | Notes |
|----------|-------------|-------|
| Gemini ([pricing](https://ai.google.dev/gemini-api/docs/pricing)) | Permanent free tier | Flash, Flash-Lite, and 2.5 Pro models on an AI Studio key with no billing account; 3.1 Pro is paid-only |
| Groq ([limits](https://console.groq.com/docs/rate-limits)) | Permanent free plan | Every production model, for example gpt-oss-120b at 30 RPM, 1K RPD, 200K TPD; no card |
| Mistral | Permanent free plan | Experiment plan: every model, about 1 request per second, opt into data training |
| OpenRouter ([limits](https://openrouter.ai/docs/api-reference/limits)) | Permanent free models | IDs ending in `:free`: 20 RPM, 50 RPD (1,000 RPD after a one-time $10 credit); the roster rotates |
| GLM ([pricing](https://docs.z.ai/guides/overview/pricing)) | Permanent free models | glm-4.7-flash, glm-4.5-flash, glm-4.6v-flash at about 1 request per second |
| Qwen ([quota](https://help.aliyun.com/zh/model-studio/new-free-quota)) | New-user quota | 1M tokens per model for 90 days, on the China site (Beijing) and the international site (Singapore) |
| Doubao | New-user quota | 500K tokens per model for new Volcengine Ark accounts |
| DeepSeek ([pricing](https://api-docs.deepseek.com/quick_start/pricing)) | Signup credit | Off-peak hours bill at half price |
| Kimi | Signup credit | ¥15 on the China platform |
| OpenAI ([pricing](https://developers.openai.com/api/docs/pricing)) | Trial credit | One-time $15 for new accounts; complimentary daily tokens for organizations that opt into data sharing |
| Claude | Trial credit | One-time $5 for new Console accounts |

Not in the catalogs but reachable through `OpenAIEndpoint(...)` plus `.custom(id)`: SiliconFlow, Tencent Hunyuan, Baidu Qianfan, MiniMax, Xiaomi MiMo, NVIDIA NIM, and local servers.

## Retry policies

Retry behavior is a parameter, not a baked-in default. Set it per app in the configuration, or override per call.

| | `.default` | `.minimal` |
|---|---|---|
| Attempts | 3 | 3 |
| Backoff | 0.8s base, 6s cap, deterministic jitter | 1s base, fixed exponential |
| `Retry-After` header | honored (clamped) | ignored |
| Retired model | retries the call on the fallback model | fails the call |
| Transport failure (and Claude's 413) | re-encodes images smaller | no re-encode |

Either way, a retired model persists a reset of the stored selection to `fallbackModel`, so the user's next call succeeds. Gemini treats every 404 as a retired model; the OpenAI-compatible and Claude clients reset only when the error body names the model, so a mistyped base URL never touches the user's selection.

## Error copy

`GeminiError`, `OpenAIError`, and `AnthropicError` descriptions resolve from each target's string catalog (en, es, zh-Hans, zh-Hant) with app-neutral wording; the OpenAI-compatible copy names the endpoint ("Groq API key not set"). Apps that want feature-specific copy ("Gemini returned a trip we couldn't read") map the cases at their feature layer.

## Example App

The `Example/` directory contains a small catalog app exercising the package end to end: a provider picker (all fourteen endpoints, China regions included), API key and model settings with live model listing, schema-constrained structured output, multi-turn chat, and the offline JSON extractor (no API key needed). It uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

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
