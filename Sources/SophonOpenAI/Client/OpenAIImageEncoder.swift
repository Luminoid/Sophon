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
            do {
                return try await LLMImageEncoder.encode(cappedImages(images), maxDimension: maxDimension, quality: quality)
            } catch is LLMImageEncodingError {
                throw OpenAIError.imageEncodingFailed
            }
        }

        /// Encode images at the size dictated by the retry variant: full size normally, down-scaled
        /// after a transport failure triggers a re-encode.
        func encodeImages(_ images: [UIImage], variant: LLMRequestVariant) async throws -> [LLMPart] {
            do {
                return try await LLMImageEncoder.encode(cappedImages(images), variant: variant)
            } catch is LLMImageEncodingError {
                throw OpenAIError.imageEncodingFailed
            }
        }

        private func cappedImages(_ images: [UIImage]) -> [UIImage] {
            guard images.count > configuration.maxImages else { return images }
            log(.warning, "encodeImages: dropping \(images.count - configuration.maxImages) image(s) over the configured maxImages of \(configuration.maxImages)")
            return Array(images.prefix(configuration.maxImages))
        }
    }
#endif
