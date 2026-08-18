import Foundation

struct CourseElement: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let courseId: UUID
    let category: ElementCategory
    let latitude: Double
    let longitude: Double
    let distanceFromStartMeters: Int
    let title: String
    let description: String
    /// Presigned read URL. It carries a fresh signature every time the server
    /// builds a response, so it is never a stable identity for the photo.
    var photoURL: URL?
    /// Kept as the raw string the server sent rather than a `Date`: its only
    /// job is to be an opaque version token for the photo cache, and parsing it
    /// would add a precision mismatch for no gain.
    var photoUploadedAt: String?

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    var hasPhoto: Bool {
        photoURL != nil && photoUploadedAt != nil
    }

    /// Identity of the photo's content, stable across responses. Nil when the
    /// element has no photo.
    var photoCacheKey: String? {
        guard let photoUploadedAt else { return nil }
        return ElementPhotoIdentity.cacheKey(elementID: id, uploadedAt: photoUploadedAt)
    }
}

enum ElementPhotoIdentity {
    /// Names a photo by what it is rather than where it is fetched from. The
    /// upload time changes only when the photo is replaced, so the same photo
    /// keeps the same name across responses even though its presigned URL does
    /// not.
    static func cacheKey(elementID: UUID, uploadedAt: String) -> String {
        // The timestamp goes into a file name, so anything outside the safe set
        // is folded to a dash.
        let version = uploadedAt.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return "\(elementID.uuidString)_\(String(version))"
    }
}
