//
//  GeminiImageEncoder.swift
//  SophonGemini
//
//  UIImage → base64 inlineData parts for multimodal requests: the shared
//  `LLMImageEncoder` behind the Gemini client's `maxImages` cap and error type.
//  UIKit-gated so the Foundation-only surface still builds on macOS hosts.
//

#if canImport(UIKit)
    import Foundation
    import SophonCore
    import UIKit

    public extension GeminiAPIClient {
        /// Default long-edge cap for uploaded photos.
        static let maxImageDimension = LLMImageEncoder.maxImageDimension
        /// Default JPEG quality for uploaded photos.
        static let imageCompressionQuality = LLMImageEncoder.imageCompressionQuality
        /// Fallback image size used when a transport failure triggers a re-encode on retry.
        static let fallbackImageDimension = LLMImageEncoder.fallbackImageDimension
        /// Fallback JPEG quality used when a transport failure triggers a re-encode on retry.
        static let fallbackCompressionQuality = LLMImageEncoder.fallbackCompressionQuality

        func encodeImages(
            _ images: [UIImage],
            maxDimension: CGFloat = GeminiAPIClient.maxImageDimension,
            quality: CGFloat = GeminiAPIClient.imageCompressionQuality
        ) async throws -> [GeminiPart] {
            do {
                return try await LLMImageEncoder.encode(cappedImages(images), maxDimension: maxDimension, quality: quality)
            } catch is LLMImageEncodingError {
                throw GeminiError.imageEncodingFailed
            }
        }

        /// Encode images at the size dictated by the retry variant: full size normally, down-scaled
        /// after a transport failure triggers a re-encode.
        func encodeImages(_ images: [UIImage], variant: GeminiRequestVariant) async throws -> [GeminiPart] {
            do {
                return try await LLMImageEncoder.encode(cappedImages(images), variant: variant)
            } catch is LLMImageEncodingError {
                throw GeminiError.imageEncodingFailed
            }
        }

        /// Drops images over `configuration.maxImages` with a warning log
        /// (Gemini's inline budget is ~20 MB).
        private func cappedImages(_ images: [UIImage]) -> [UIImage] {
            guard images.count > configuration.maxImages else { return images }
            log(.warning, "encodeImages: dropping \(images.count - configuration.maxImages) image(s) over the configured maxImages of \(configuration.maxImages)")
            return Array(images.prefix(configuration.maxImages))
        }
    }
#endif
