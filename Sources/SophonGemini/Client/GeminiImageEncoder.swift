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
            try await encodeImages(images, variant: nil, maxDimension: maxDimension, quality: quality)
        }

        /// Encode images at the size dictated by the retry variant: full size normally, down-scaled
        /// after a transport failure or a 413 triggers a re-encode.
        func encodeImages(_ images: [UIImage], variant: GeminiRequestVariant) async throws -> [GeminiPart] {
            try await encodeImages(images, variant: variant, maxDimension: Self.maxImageDimension, quality: Self.imageCompressionQuality)
        }

        private func encodeImages(_ images: [UIImage], variant: LLMRequestVariant?, maxDimension: CGFloat, quality: CGFloat) async throws -> [LLMPart] {
            let capped = LLMImageEncoder.capped(images, maxImages: configuration.maxImages, log: log)
            do {
                return try await LLMImageEncoder.encode(capped, variant: variant, maxDimension: maxDimension, quality: quality)
            } catch is LLMImageEncodingError {
                throw GeminiError.imageEncodingFailed
            }
        }
    }
#endif
