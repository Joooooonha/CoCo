import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import CoCo

struct ElementPhotoProcessorTests {
    /// The whole reason for re-encoding: a photo taken on a phone carries the
    /// capture location, and sharing a course must not share where the runner
    /// was standing.
    @Test
    func processingRemovesCaptureLocation() throws {
        let original = try photoCarryingLocation()
        #expect(locationMetadata(of: original) != nil, "픽스처 자체에 위치 정보가 있어야 의미 있는 검증이 된다")

        let processed = try ElementPhotoProcessor().process(original)

        #expect(locationMetadata(of: processed.data) == nil)
    }

    @Test
    func largePhotosAreShrunkToTheLongEdgeLimit() throws {
        let data = try jpeg(width: 4_032, height: 3_024)

        let processed = try ElementPhotoProcessor().process(data)

        #expect(processed.pixelSize.width == ElementPhotoProcessor.maximumLongEdge)
        #expect(processed.pixelSize.height == 1_200)
    }

    @Test
    func portraitPhotosAreShrunkByTheirHeight() throws {
        let data = try jpeg(width: 3_024, height: 4_032)

        let processed = try ElementPhotoProcessor().process(data)

        #expect(processed.pixelSize.height == ElementPhotoProcessor.maximumLongEdge)
        #expect(processed.pixelSize.width == 1_200)
    }

    /// Small photos still go through the redraw, because that is what drops the
    /// metadata. Only their dimensions are left alone.
    @Test
    func smallPhotosKeepTheirSizeButStillLoseMetadata() throws {
        let data = try photoCarryingLocation(width: 800, height: 600)

        let processed = try ElementPhotoProcessor().process(data)

        #expect(processed.pixelSize == CGSize(width: 800, height: 600))
        #expect(locationMetadata(of: processed.data) == nil)
    }

    @Test
    func outputStaysWithinTheServerUploadLimit() throws {
        let processed = try ElementPhotoProcessor().process(try jpeg(width: 4_032, height: 3_024))

        #expect(processed.data.count <= ElementPhotoProcessor.maximumUploadBytes)
        #expect(processed.contentType == "image/jpeg")
    }

    @Test
    func nonImageDataIsRejected() {
        let processor = ElementPhotoProcessor()

        #expect(throws: ElementPhotoProcessor.ProcessingError.unreadableImage) {
            try processor.process(Data("not an image".utf8))
        }
    }

    // MARK: - Fixtures

    /// Draws a gradient rather than a flat fill so JPEG has something to encode
    /// and the size assertions are not measuring an empty image.
    private func jpeg(width: Int, height: Int) throws -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor.systemTeal.cgColor, UIColor.systemOrange.cgColor] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw TestFixtureError.encodingFailed
        }
        return data
    }

    private func photoCarryingLocation(width: Int = 2_400, height: Int = 1_600) throws -> Data {
        let base = try jpeg(width: width, height: height)
        guard let source = CGImageSourceCreateWithData(base as CFData, nil) else {
            throw TestFixtureError.encodingFailed
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw TestFixtureError.encodingFailed
        }

        // 서울시청 좌표. 실제 촬영 사진이 담고 오는 것과 같은 형태다.
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 37.5665,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 126.9780,
            kCGImagePropertyGPSLongitudeRef: "E"
        ]
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            [kCGImagePropertyGPSDictionary: gps] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw TestFixtureError.encodingFailed
        }
        return output as Data
    }

    private func locationMetadata(of data: Data) -> [CFString: Any]? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return nil
        }
        return properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    }

    private enum TestFixtureError: Error {
        case encodingFailed
    }
}
