# ``SophonOpenAI``

One client for OpenAI's Responses API and every OpenAI-compatible endpoint.

## Overview

``OpenAICompatibleClient`` is generic over a catalog that conforms to ``OpenAICompatibleModel``; the catalog supplies the ``OpenAIEndpoint`` (base URL, wire format, structured-output mode, auth header shape). Presets ship for OpenAI, Groq, Mistral, OpenRouter, DeepSeek, Qwen, GLM, Kimi, and Doubao, each with `<Name>ClientConfiguration` and `<Name>APIClient` aliases. Any other compatible server takes a custom ``OpenAIEndpoint`` plus `.custom(id)` models.

## Topics

### Client

- ``OpenAICompatibleClient``
- ``OpenAICompatibleConfiguration``
- ``OpenAIEndpoint``
- ``OpenAIError``

### Catalogs

- ``OpenAICompatibleModel``
- ``OpenAIModel``
- ``GroqModel``
- ``MistralModel``
- ``OpenRouterModel``
- ``DeepSeekModel``
- ``QwenModel``
- ``GLMModel``
- ``KimiModel``
- ``DoubaoModel``
