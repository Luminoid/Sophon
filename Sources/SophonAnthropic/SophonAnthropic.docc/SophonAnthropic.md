# ``SophonAnthropic``

The Claude Messages API client, on top of `SophonCore`.

## Overview

Build an ``AnthropicClientConfiguration`` with your app's Keychain account and keep one shared ``AnthropicAPIClient``. Structured output rides in `output_config`, images and PDFs go as content blocks, system messages are hoisted into `system`, and an oversized request is retried once with smaller images when the request builder can re-encode them.

## Topics

### Client

- ``AnthropicAPIClient``
- ``AnthropicClientConfiguration``
- ``AnthropicEffort``
- ``AnthropicError``

### Catalog

- ``AnthropicModel``
