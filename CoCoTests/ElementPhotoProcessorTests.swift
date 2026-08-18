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

    /// Re-encoding does not produce a metadata-free file: the encoder writes a
    /// fresh EXIF block of its own. What matters is that nothing identifying
    /// the photographer, the device or the moment survives.
    @Test
    func processingRemovesEveryIdentifyingTagEvenThoughAnExifBlockRemains() throws {
        let processed = try ElementPhotoProcessor().process(try photoCarryingIdentifyingMetadata())

        let properties = imageProperties(of: processed.data)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        #expect(tiff[kCGImagePropertyTIFFMake] == nil)
        #expect(tiff[kCGImagePropertyTIFFModel] == nil)

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(exif[kCGImagePropertyExifUserComment] == nil)
        // The encoder's own tags are fine to keep; they describe the bitmap,
        // not the person who took it.
        #expect(exif[kCGImagePropertyExifPixelXDimension] != nil)
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

    /// Small photos still go through the redraw, because that is what sheds the
    /// original metadata. Only their dimensions are left alone.
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
        imageProperties(of: data)[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    }

    private func imageProperties(of data: Data) -> [CFString: Any] {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return [:]
        }
        return properties
    }

    /// A photo as it comes off a phone: capture location, capture time and the
    /// device that took it.
    private func photoCarryingIdentifyingMetadata() throws -> Data {
        let base = try jpeg(width: 2_400, height: 1_600)
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

        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.5665,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 126.9780,
                kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 16 Pro"
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:08:18 07:31:02",
                kCGImagePropertyExifUserComment: "달리기 전 한 컷"
            ]
        ]
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw TestFixtureError.encodingFailed
        }
        return output as Data
    }

    private enum TestFixtureError: Error {
        case encodingFailed
    }
}
