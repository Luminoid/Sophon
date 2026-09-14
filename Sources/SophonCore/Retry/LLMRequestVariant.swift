//
//  LLMRequestVariant.swift
//  SophonCore
//
//  Per-attempt knobs the retry loop hands to the request builder: whether to
//  down-scale the images (used after a transport failure) and which model ID to
//  target (swapped when the selected model turns out to be retired).
//

import Foundation

public struct LLMRequestVariant: Sendable {
    public let useCompressedImages: Bool
    public let modelID: String

    public init(useCompressedImages: Bool, modelID: String) {
        self.useCompressedImages = useCompressedImages
        self.modelID = modelID
    }
}
