//
//  LLMImageEncoder.swift
//  SophonCore
//
//  UIImage → base64 inline-data parts for multimodal requests, shared by every
//  provider client. UIKit-gated so the Foundation-only surface still builds on
//  macOS hosts.
//

#if canImport(UIKit)
    import Foundation
    import UIKit

    public enum LLMImageEncodingError: Error {
        case jpegEncodingFailed
    }

    public enum LLMImageEncoder {
        /// Default long-edge cap for uploaded photos.
        public static let maxImageDimension: CGFloat = 2048
        /// Default JPEG quality for uploaded photos.
        public static let imageCompressionQuality: CGFloat = 0.8
        /// Fallback image size used when a transport failure triggers a re-encode on retry.
        public static let fallbackImageDimension: CGFloat = 1024
        /// Fallback JPEG quality used when a transport failure triggers a re-encode on retry.
        public static let fallbackCompressionQuality: CGFloat = 0.6

        /// Resize and JPEG-encode each image into an inline part, preserving
        /// input order. Runs off the caller's executor; callers apply their own
        /// image-count cap before calling.
        public static func encode(
            _ images: [UIImage],
            maxDimension: CGFloat = maxImageDimension,
            quality: CGFloat = imageCompressionQuality
        ) async throws -> [LLMPart] {
            // Resize inside the child tasks: a UIGraphicsImageRenderer redraw of a
            // large photo is tens of milliseconds and must not run on the MainActor.
            try await withThrowingTaskGroup(of: (Int, LLMPart).self) { group in
                for (index, image) in images.enumerated() {
                    group.addTask {
                        let resized = resizeIfNeeded(image, maxDimension: maxDimension)
                        guard let data = resized.jpegData(compressionQuality: quality) else {
                            throw LLMImageEncodingError.jpegEncodingFailed
                        }
                        return (index, LLMPart.inlineData(mimeType: "image/jpeg", data: data.base64EncodedString()))
                    }
                }
                var results: [(Int, LLMPart)] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
        }

        /// Encode images at the size dictated by the retry variant: full size
        /// normally, down-scaled after a transport failure triggers a re-encode.
        public static func encode(_ images: [UIImage], variant: LLMRequestVariant) async throws -> [LLMPart] {
            if variant.useCompressedImages {
                return try await encode(images, maxDimension: fallbackImageDimension, quality: fallbackCompressionQuality)
            }
            return try await encode(images)
        }

        private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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
