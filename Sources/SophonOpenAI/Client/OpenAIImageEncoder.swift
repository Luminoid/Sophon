//
//  OpenAIImageEncoder.swift
//  SophonOpenAI
//
//  UIImage → base64 inline parts for multimodal requests: the shared
//  `LLMImageEncoder` behind the client's `maxImages` cap and error type.
//  UIKit-gated so the Foundation-only surface still builds on macOS hosts.
//

#if canImport(UIKit)
    import Foundation
    import SophonCore
    import UIKit

    public extension OpenAICompatibleClient {
        func encodeImages(
            _ images: [UIImage],
            maxDimension: CGFloat = LLMImageEncoder.maxImageDimension,
            quality: CGFloat = LLMImageEncoder.imageCompressionQuality
        ) async throws -> [LLMPart] {
            try await encodeImages(images, variant: nil, maxDimension: maxDimension, quality: quality)
        }

        /// Encode images at the size dictated by the retry variant: full size normally, down-scaled
        /// after a transport failure or a 413 triggers a re-encode.
        func encodeImages(_ images: [UIImage], variant: LLMRequestVariant) async throws -> [LLMPart] {
            try await encodeImages(images, variant: variant, maxDimension: LLMImageEncoder.maxImageDimension, quality: LLMImageEncoder.imageCompressionQuality)
        }

        private func encodeImages(_ images: [UIImage], variant: LLMRequestVariant?, maxDimension: CGFloat, quality: CGFloat) async throws -> [LLMPart] {
            let capped = LLMImageEncoder.capped(images, maxImages: configuration.maxImages, log: log)
            do {
                return try await LLMImageEncoder.encode(capped, variant: variant, maxDimension: maxDimension, quality: quality)
            } catch is LLMImageEncodingError {
                throw OpenAIError.imageEncodingFailed
            }
        }
    }
#endif
