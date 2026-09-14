//
//  AnthropicModelStore.swift
//  SophonAnthropic
//
//  Persistence and per-app resolution for the model selection: the shared
//  `LLMModelStore` specialized for the Claude catalog, built by
//  `AnthropicClientConfiguration.modelStore`.
//

import SophonCore

public typealias AnthropicModelStore = LLMModelStore<AnthropicModel>
