//
//  GeminiCompatibility.swift
//  SophonGemini
//
//  The Gemini-era names of the shared Core types, so every consumer written
//  against Sophon 0.1 / 0.2 keeps compiling. `GeminiSchema` encoded directly
//  still produces Gemini's `responseSchema` dialect (uppercase types,
//  `propertyOrdering`); `GeminiPart` / `GeminiContent` still encode in the
//  0.1 JSON shape. `GeminiModelStore.init(configuration:)` lives in
//  `Model/GeminiModelStore.swift`.
//

import SophonCore

public typealias GeminiSchema = LLMSchema
public typealias GeminiPart = LLMPart
public typealias GeminiContent = LLMMessage
public typealias GeminiRetryPolicy = LLMRetryPolicy
public typealias GeminiRequestVariant = LLMRequestVariant
public typealias GeminiModelStore = LLMModelStore<GeminiModel>
