//
//  OpenAICompatibleModel.swift
//  SophonOpenAI
//
//  A model catalog that is served over the OpenAI-compatible wire, carrying the
//  endpoint its provider answers on. One generic client and configuration
//  serve every catalog that conforms.
//

import Foundation
import SophonCore

public protocol OpenAICompatibleModel: LLMModelPreset {
    /// The endpoint a configuration uses unless told otherwise (the
    /// international region for providers that have a China split).
    static var defaultEndpoint: OpenAIEndpoint { get }
}

public extension OpenAICompatibleModel {
    /// The default endpoint's key hint, so every catalog answers
    /// `keyHintURL` the same way.
    static var keyHintURL: URL? { defaultEndpoint.keyHintURL }
}
