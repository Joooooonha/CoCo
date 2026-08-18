import UIKit

/// Prepares a picked photo for upload.
///
/// Redrawing the image into a fresh bitmap is what removes the original
/// metadata: nothing is copied over, so the capture location and time cannot
/// survive. It also bakes in the orientation, so no orientation tag is needed
/// in the result either.
struct ElementPhotoProcessor {
    struct Output: Equatable, Sendable {
        let data: Data
        /// Always JPEG. Re-encoding is how the metadata gets dropped, so there
        /// is no path that forwards the original HEIC bytes.
        let contentType: String
        let pixelSize: CGSize
    }

    enum ProcessingError: LocalizedError, Equatable {
        case unreadableImage
        case tooLargeToCompress

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                "이 사진을 읽을 수 없어요. 다른 사진을 선택해 주세요."
            case .tooLargeToCompress:
                "사진 용량을 줄이지 못했어요. 다른 사진을 선택해 주세요."
            }
        }
    }

    /// Matches the server limit in `ElementPhotoService`.
    static let maximumUploadBytes = 5 * 1024 * 1024
    /// A course element photo is shown at most full-width in a sheet, so a
    /// longer edge than this buys nothing a runner can see.
    static let maximumLongEdge: CGFloat = 1_600
    /// Tried in order until the encoded size fits. Dropping quality distorts
    /// less than shrinking further, so dimensions stay fixed.
    private static let qualitySteps: [CGFloat] = [0.8, 0.6, 0.45, 0.3]

    func process(_ data: Data) throws -> Output {
        guard let image = UIImage(data: data) else {
            throw ProcessingError.unreadableImage
        }

        let normalized = Self.redrawn(image)
        for quality in Self.qualitySteps {
            guard let encoded = normalized.jpegData(compressionQuality: quality) else {
                throw ProcessingError.unreadableImage
            }
            if encoded.count <= Self.maximumUploadBytes {
                return Output(data: encoded, contentType: "image/jpeg", pixelSize: normalized.size)
            }
        }
        throw ProcessingError.tooLargeToCompress
    }

    /// Runs even when the image already fits, because the redraw is the step
    /// that strips metadata rather than an optimization.
    private static func redrawn(_ image: UIImage) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        let ratio = longEdge > maximumLongEdge ? maximumLongEdge / longEdge : 1
        let target = CGSize(
            width: max(1, (image.size.width * ratio).rounded()),
            height: max(1, (image.size.height * ratio).rounded())
        )

        let format = UIGraphicsImageRendererFormat.default()
        // Point and pixel sizes have to match, or the encoded image comes out
        // at the simulator's screen scale instead of the size asked for.
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
