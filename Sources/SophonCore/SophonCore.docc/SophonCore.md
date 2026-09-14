# ``SophonCore``

The provider-neutral kernel every Sophon client is built on.

## Overview

`SophonCore` owns the shapes: a schema written once and encoded in each provider's dialect, role-tagged messages and parts, the retry policy and loop, model catalogs with lifecycle and free-tier metadata, the configuration and client protocols, and lenient decoding for the JSON that language models actually return. The provider targets (`SophonGemini`, `SophonOpenAI`, `SophonAnthropic`) map these onto their wire formats.

An app usually imports a provider target, which re-exports this module. Import `SophonCore` directly to write provider-agnostic code against ``LLMClient``.

## Topics

### Structured output

- ``LLMSchema``
- ``LLMSchemaDialect``
- ``LLMSchemaDocument``
- ``LLMDecoding``
- ``LLMJSONExtractor``

### Messages

- ``LLMMessage``
- ``LLMPart``
- ``LLMRole``

### Retry

- ``LLMRetryPolicy``
- ``LLMRetryLoop``
- ``LLMRequestVariant``
- ``LLMClientError``
- ``LLMHTTP``

### Model catalogs

- ``LLMModelPreset``
- ``LLMModelInfo``
- ``LLMModelStore``
- ``LLMCatalogAudit``
- ``LLMProviderFreeAccess``

### Configuration and clients

- ``LLMProviderConfiguration``
- ``LLMAPIKeyStatus``
- ``LLMClient``
- ``LLMRemoteModel``
- ``LLMErrorCopy``
- ``SophonKeychain``
- ``SophonLog``
