//
//  LLMImageEncoder.swift
//  SophonCore
//
//  UIImage → base64 inline-data parts for multimodal requests, shared by every
//  provider client: the per-request image cap, the retry-variant size switch,
//  and bounded off-main resize + JPEG encoding. UIKit-gated so the
//  Foundation-only surface still builds on macOS hosts.
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
        /// Fallback image size used when a transport failure or a 413 triggers a re-encode on retry.
        public static let fallbackImageDimension: CGFloat = 1024
        /// Fallback JPEG quality used when a transport failure or a 413 triggers a re-encode on retry.
        public static let fallbackCompressionQuality: CGFloat = 0.6

        /// Images encoded at once. Each in-flight image holds a resized bitmap,
        /// its JPEG, and the base64 string, so the bound keeps peak memory flat
        /// for callers that raise `maxImages`.
        private static let concurrentEncodes = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount))

        /// The first `maxImages` images (a negative cap counts as zero), logging
        /// a warning for any dropped. Synchronous, so a client can log on its
        /// own actor before handing the images to `encode`.
        public static func capped(_ images: [UIImage], maxImages: Int, log: (SophonLogLevel, String) -> Void) -> [UIImage] {
            let cap = max(0, maxImages)
            guard images.count > cap else { return images }
            log(.warning, "encodeImages: dropping \(images.count - cap) image(s) over the configured maxImages of \(maxImages)")
            return Array(images.prefix(cap))
        }

        /// Encode images at the size the retry `variant` dictates: `maxDimension`
        /// and `quality` normally (also for a nil variant), the fallback size
        /// after a transport failure or a 413 triggers a re-encode.
        public static func encode(
            _ images: [UIImage],
            variant: LLMRequestVariant?,
            maxDimension: CGFloat = maxImageDimension,
            quality: CGFloat = imageCompressionQuality
        ) async throws -> [LLMPart] {
            if let variant, variant.useCompressedImages {
                return try await encode(images, maxDimension: fallbackImageDimension, quality: fallbackCompressionQuality)
            }
            return try await encode(images, maxDimension: maxDimension, quality: quality)
        }

        /// Resize and JPEG-encode each image into an inline part, preserving
        /// input order. Runs off the caller's executor, at most
        /// `concurrentEncodes` images at a time.
        public static func encode(
            _ images: [UIImage],
            maxDimension: CGFloat = maxImageDimension,
            quality: CGFloat = imageCompressionQuality
        ) async throws -> [LLMPart] {
            // Resize inside the child tasks: a UIGraphicsImageRenderer redraw of a
            // large photo is tens of milliseconds and must not run on the MainActor.
            try await withThrowingTaskGroup(of: (Int, LLMPart).self) { group in
                var results: [(Int, LLMPart)] = []
                for (index, image) in images.enumerated() {
                    if index >= concurrentEncodes, let finished = try await group.next() {
                        results.append(finished)
                    }
                    group.addTask {
                        let resized = resizeIfNeeded(image, maxDimension: maxDimension)
                        guard let data = resized.jpegData(compressionQuality: quality) else {
                            throw LLMImageEncodingError.jpegEncodingFailed
                        }
                        return (index, LLMPart.inlineData(mimeType: "image/jpeg", data: data.base64EncodedString()))
                    }
                }
                for try await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
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
