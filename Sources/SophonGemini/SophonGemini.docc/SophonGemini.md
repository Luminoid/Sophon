# ``SophonGemini``

The Gemini API client, on top of `SophonCore`.

## Overview

Build a ``GeminiClientConfiguration`` with your app's Keychain account and keep one shared ``GeminiAPIClient``. The ``GeminiModel`` catalog carries lifecycle and free-tier metadata, so `defaultModel`, `fallbackModel`, and `availableModels` can be left to Sophon. Gemini-era names (`GeminiSchema`, `GeminiPart`, `GeminiContent`, `GeminiRetryPolicy`, `GeminiRequestVariant`, `GeminiModelStore`) are aliases onto the Core types.

## Topics

### Client

- ``GeminiAPIClient``
- ``GeminiClientConfiguration``
- ``GeminiError``

### Catalog

- ``GeminiModel``
