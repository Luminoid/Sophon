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
            var images = images
            if images.count > configuration.maxImages {
                log(.warning, "encodeImages: dropping \(images.count - configuration.maxImages) image(s) over the configured maxImages of \(configuration.maxImages)")
                images = Array(images.prefix(configuration.maxImages))
            }
            // Resize inside the child tasks: a UIGraphicsImageRenderer redraw of a
            // large photo is tens of milliseconds and must not run on the MainActor.
            return try await withThrowingTaskGroup(of: (Int, GeminiPart).self) { group in
                for (index, image) in images.enumerated() {
                    group.addTask {
                        let resized = Self.resizeIfNeeded(image, maxDimension: maxDimension)
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

        /// nonisolated so the task-group children can run it off the MainActor.
        private nonisolated static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let size = image.size
            let maxSize = max(size.width, size.height)
            guard maxSize > maxDimension else { return image }

            let scale = maxDimension / maxSize
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            // Pin the renderer to scale 1 so the cap means pixels: the default
            // format uses the device's screen scale, which would render a
            // "2048" cap as 6144 actual pixels on a 3x display.
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
#endif
