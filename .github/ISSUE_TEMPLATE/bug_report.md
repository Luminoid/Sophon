---
name: Bug report
about: A Sophon API misbehaves, a request fails unexpectedly, or the package does not build
title: ''
labels: bug
---

**What did you do?**

<!-- The smallest call site that reproduces it. A failing test in Tests/ is ideal. -->

```swift
let result = try await GeminiAPIClient.shared.generateStructured(...)
```

**What did you expect?**

**What happened instead?**

<!-- Thrown GeminiError, decoded value, or compiler error. Redact API keys and personal data. -->

**Environment**

- Sophon version (tag or commit):
- Retry policy in use (`.default` / `.minimal` / custom):
- Gemini model ID:
- Xcode version (`xcodebuild -version`):
- Platform and OS version (iOS / iPadOS / Mac Catalyst / macOS; simulator or device):
