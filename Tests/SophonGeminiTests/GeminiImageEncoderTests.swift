//
//  GeminiImageEncoderTests.swift
//  SophonGeminiTests
//
//  Unit tests for the UIKit-gated image encoder: part construction, input-order
//  preservation, the pixel-true resize cap, and maxImages enforcement.
//

#if canImport(UIKit)
    import Foundation
    import SophonGemini
    import Testing
    import UIKit

    @MainActor
    struct GeminiImageEncoderTests {
        private let client = GeminiAPIClient(configuration: TestSupport.makeConfiguration())

        /// A solid-color image at scale 1, so point sizes equal pixel sizes.
        private static func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            return renderer.image { context in
                UIColor.systemRed.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
        }

        private func decodedImage(from part: GeminiPart) throws -> UIImage {
            guard case let .inlineData(mimeType, base64) = part,
                  mimeType == "image/jpeg",
                  let data = Data(base64Encoded: base64),
                  let image = UIImage(data: data) else {
                throw GeminiError.imageEncodingFailed
            }
            return image
        }

        @Test
        func `encodeImages returns one JPEG part per image, preserving input order`() async throws {
            let wide = Self.makeImage(width: 40, height: 20)
            let tall = Self.makeImage(width: 20, height: 40)

            let parts = try await client.encodeImages([wide, tall])

            #expect(parts.count == 2)
            let first = try decodedImage(from: parts[0])
            let second = try decodedImage(from: parts[1])
            #expect(first.size.width > first.size.height)
            #expect(second.size.height > second.size.width)
        }

        @Test
        func `encodeImages caps the long edge in pixels`() async throws {
            let big = Self.makeImage(width: 100, height: 50)

            let parts = try await client.encodeImages([big], maxDimension: 50)

            let resized = try decodedImage(from: parts[0])
            #expect(max(resized.size.width, resized.size.height) == 50)
            #expect(min(resized.size.width, resized.size.height) == 25)
        }

        @Test
        func `encodeImages leaves images within the cap untouched`() async throws {
            let small = Self.makeImage(width: 30, height: 20)

            let parts = try await client.encodeImages([small], maxDimension: 50)

            let unchanged = try decodedImage(from: parts[0])
            #expect(unchanged.size == CGSize(width: 30, height: 20))
        }

        @Test
        func `encodeImages drops images beyond the configured maxImages`() async throws {
            let capped = GeminiAPIClient(configuration: TestSupport.makeConfiguration(maxImages: 2))
            let image = Self.makeImage(width: 10, height: 10)

            let parts = try await capped.encodeImages([image, image, image])

            #expect(parts.count == 2)
        }
    }
#endif
