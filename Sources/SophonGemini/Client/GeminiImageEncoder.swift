//
//  GeminiImageEncoder.swift
//  SophonGemini
//
//  UIImage → base64 inlineData parts for multimodal requests. UIKit-gated so
//  the Foundation-only surface still builds on macOS hosts.
//

#if canImport(UIKit)
    import Foundation
    import UIKit

    public extension GeminiAPIClient {
        /// Default long-edge cap for uploaded photos.
        static let maxImageDimension: CGFloat = 2048
        /// Default JPEG quality for uploaded photos.
        static let imageCompressionQuality: CGFloat = 0.8
        /// Fallback image size used when a transport failure triggers a re-encode on retry.
        static let fallbackImageDimension: CGFloat = 1024
        /// Fallback JPEG quality used when a transport failure triggers a re-encode on retry.
        static let fallbackCompressionQuality: CGFloat = 0.6

        func encodeImages(
            _ images: [UIImage],
            maxDimension: CGFloat = GeminiAPIClient.maxImageDimension,
            quality: CGFloat = GeminiAPIClient.imageCompressionQuality
        ) async throws -> [GeminiPart] {
            try await withThrowingTaskGroup(of: (Int, GeminiPart).self) { group in
                for (index, image) in images.enumerated() {
                    let resized = Self.resizeIfNeeded(image, maxDimension: maxDimension)
                    group.addTask {
                        guard let data = resized.jpegData(compressionQuality: quality) else {
                            throw GeminiError.imageEncodingFailed
                        }
                        return (index, GeminiPart.inlineData(mimeType: "image/jpeg", data: data.base64EncodedString()))
                    }
                }
                var results: [(Int, GeminiPart)] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
        }

        /// Encode images at the size dictated by the retry variant: full size normally, down-scaled
        /// after a transport failure triggers a re-encode.
        func encodeImages(_ images: [UIImage], variant: GeminiRequestVariant) async throws -> [GeminiPart] {
            if variant.useCompressedImages {
                return try await encodeImages(
                    images,
                    maxDimension: Self.fallbackImageDimension,
                    quality: Self.fallbackCompressionQuality
                )
            }
            return try await encodeImages(images)
        }

        private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let size = image.size
            let maxSize = max(size.width, size.height)
            guard maxSize > maxDimension else { return image }

            let scale = maxDimension / maxSize
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
#endif
