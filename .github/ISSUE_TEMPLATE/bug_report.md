---
name: Bug report
about: A Sophon API misbehaves, a request fails unexpectedly, or the package does not build
title: ''
labels: bug
---

**What did you do?**

<!-- The smallest call site that reproduces it. A failing test in Tests/ is ideal. -->

```swift
let result = try await client.generateStructured(...) // GeminiAPIClient, an OpenAICompatibleClient, or AnthropicAPIClient
```

**What did you expect?**

**What happened instead?**

<!-- Thrown error (GeminiError / OpenAIError / AnthropicError), decoded value, or compiler error. Redact API keys and personal data. -->

**Environment**

- Sophon version (tag or commit):
- Provider and endpoint (Gemini / OpenAI / Groq / Mistral / OpenRouter / DeepSeek / Qwen / GLM / Kimi / Doubao / Claude / custom `OpenAIEndpoint`; region if any):
- Model ID:
- Retry policy in use (`.default` / `.minimal` / custom):
- Xcode version (`xcodebuild -version`):
- Platform and OS version (iOS / iPadOS / Mac Catalyst / macOS; simulator or device):
