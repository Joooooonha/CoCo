import Foundation
import Testing

@testable import CoCo

/// Covers the rules the draft carries between picking a photo and saving it.
struct ElementDraftPhotoTests {
    @Test
    func aDraftFromAnElementCarriesItsSavedPhoto() {
        let element = element(photoUploadedAt: "2026-08-17T12:50:07.123456Z")

        let draft = ElementDraft(element: element)

        #expect(draft.savedPhoto?.uploadedAt == "2026-08-17T12:50:07.123456Z")
        #expect(draft.hasVisiblePhoto)
        #expect(draft.pendingPhoto == nil)
        #expect(!draft.removesSavedPhoto)
    }

    /// A photo URL with no upload time cannot be cached or identified, so it is
    /// treated as no photo at all rather than a half-usable one.
    @Test
    func anElementMissingTheUploadTimeCountsAsHavingNoPhoto() {
        var element = element(photoUploadedAt: nil)
        element.photoURL = URL(string: "https://storage.test/read/b.jpg?sig=1")

        #expect(!element.hasPhoto)
        #expect(element.photoCacheKey == nil)
        #expect(!ElementDraft(element: element).hasVisiblePhoto)
    }

    @Test
    func removingThenPickingAgainCancelsTheRemoval() {
        var draft = ElementDraft(element: element(photoUploadedAt: "2026-08-17T12:50:07.123456Z"))

        draft.removesSavedPhoto = true
        #expect(!draft.hasVisiblePhoto)

        draft.pendingPhoto = ElementPhotoProcessor.Output(
            data: Data([0x01]),
            contentType: "image/jpeg",
            pixelSize: CGSize(width: 10, height: 10)
        )
        draft.removesSavedPhoto = false

        #expect(draft.hasVisiblePhoto)
    }

    /// The file name has to survive being written to disk, and the server sends
    /// a timestamp full of colons and dots.
    @Test
    func cacheKeysContainOnlySafeFileNameCharacters() {
        let key = ElementPhotoIdentity.cacheKey(
            elementID: UUID(uuidString: "B7F3D201-0000-0000-0000-00000000009F")!,
            uploadedAt: "2026-08-17T12:50:07.123456Z"
        )

        #expect(key == "B7F3D201-0000-0000-0000-00000000009F_2026-08-17T12-50-07-123456Z")
        #expect(!key.contains(":"))
        #expect(!key.contains("/"))
    }

    @Test
    func differentElementsWithTheSameUploadTimeGetDifferentKeys() {
        let uploadedAt = "2026-08-17T12:50:07.123456Z"

        let first = ElementPhotoIdentity.cacheKey(elementID: UUID(), uploadedAt: uploadedAt)
        let second = ElementPhotoIdentity.cacheKey(elementID: UUID(), uploadedAt: uploadedAt)

        #expect(first != second)
    }

    private func element(photoUploadedAt: String?) -> CourseElement {
        CourseElement(
            id: UUID(),
            courseId: UUID(),
            category: .view,
            latitude: 37.5,
            longitude: 126.9,
            distanceFromStartMeters: 400,
            title: "강변 전망",
            description: "노을이 잘 보이는 구간",
            photoURL: photoUploadedAt == nil ? nil : URL(string: "https://storage.test/read/b.jpg?sig=1"),
            photoUploadedAt: photoUploadedAt
        )
    }
}
