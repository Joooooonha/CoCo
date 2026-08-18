import Foundation
import Testing
import UIKit

@testable import CoCo

struct ElementPhotoCacheTests {
    @Test
    func storedPhotosComeBackByTheirKey() async {
        let cache = makeCache()
        let photo = Data(repeating: 0x7F, count: 512)

        await cache.store(photo, for: "element_v1")

        #expect(await cache.data(for: "element_v1") == photo)
        #expect(await cache.data(for: "element_v2") == nil)
    }

    /// The whole point of the key: replacing a photo changes the upload time,
    /// so the old bytes can never be served for the new photo.
    @Test
    func replacingAPhotoMissesTheOldEntry() async {
        let cache = makeCache()
        let element = element(uploadedAt: "2026-08-17T12:50:07.123456Z")
        await cache.store(Data("old".utf8), for: element.photoCacheKey!)

        let replaced = self.element(uploadedAt: "2026-08-18T09:11:42.000001Z")

        #expect(await cache.data(for: replaced.photoCacheKey!) == nil)
    }

    @Test
    func oldestEntriesAreDroppedWhenTheCacheIsFull() async {
        let cache = makeCache(capacityBytes: 10_000)
        let photo = Data(repeating: 0x01, count: 2_000)

        for index in 0..<4 {
            await cache.store(photo, for: "photo-\(index)")
            // The eviction order is file modification time, which has a coarse
            // enough resolution that writes need separating.
            try? await Task.sleep(for: .milliseconds(20))
        }
        // Reading photo-0 makes it the most recently used, so the next write
        // must evict something else instead.
        _ = await cache.data(for: "photo-0")
        try? await Task.sleep(for: .milliseconds(20))
        await cache.store(photo, for: "photo-4")
        await cache.store(photo, for: "photo-5")

        #expect(await cache.currentSizeBytes() <= 10_000)
        #expect(await cache.data(for: "photo-0") != nil, "방금 읽은 항목이 먼저 사라지면 LRU가 아니다")
        #expect(await cache.data(for: "photo-5") != nil)
        #expect(await cache.data(for: "photo-1") == nil)
    }

    @Test
    func clearingRemovesEverything() async {
        let cache = makeCache()
        await cache.store(Data("photo".utf8), for: "element_v1")

        await cache.removeAll()

        #expect(await cache.data(for: "element_v1") == nil)
        #expect(await cache.currentSizeBytes() == 0)
    }

    // MARK: - Loader

    @Test
    func theSecondLoadOfTheSamePhotoSkipsTheNetwork() async {
        let cache = makeCache()
        let downloads = DownloadCounter()
        let bytes = jpegData()
        var loader = ElementPhotoLoader()
        loader.cache = cache
        loader.fetch = { _ in
            await downloads.record()
            return bytes
        }
        let element = element(uploadedAt: "2026-08-17T12:50:07.123456Z")

        #expect(await loader.image(for: element) != nil)
        #expect(await loader.image(for: element) != nil)

        #expect(await downloads.count == 1)
    }

    /// A presigned URL expires, and the response body then is an error page
    /// rather than an image. Caching it would make the failure permanent.
    @Test
    func anUndecodableDownloadIsNotCached() async {
        let cache = makeCache()
        var loader = ElementPhotoLoader()
        loader.cache = cache
        loader.fetch = { _ in Data("<Error>AccessDenied</Error>".utf8) }
        let element = element(uploadedAt: "2026-08-17T12:50:07.123456Z")

        #expect(await loader.image(for: element) == nil)
        #expect(await cache.data(for: element.photoCacheKey!) == nil)
    }

    @Test
    func elementsWithoutAPhotoNeverReachTheNetwork() async {
        let downloads = DownloadCounter()
        var loader = ElementPhotoLoader()
        loader.cache = makeCache()
        loader.fetch = { _ in
            await downloads.record()
            return Data()
        }

        #expect(await loader.image(for: element(uploadedAt: nil)) == nil)
        #expect(await downloads.count == 0)
    }

    // MARK: - Support

    private func makeCache(capacityBytes: Int = ElementPhotoCache.defaultCapacityBytes) -> ElementPhotoCache {
        ElementPhotoCache(
            directory: URL.temporaryDirectory.appending(path: "PhotoCacheTests-\(UUID().uuidString)"),
            capacityBytes: capacityBytes
        )
    }

    private func element(uploadedAt: String?) -> CourseElement {
        CourseElement(
            id: UUID(uuidString: "B7F3D201-0000-0000-0000-00000000009F")!,
            courseId: UUID(),
            category: .view,
            latitude: 37.5,
            longitude: 126.9,
            distanceFromStartMeters: 400,
            title: "강변 전망",
            description: "노을이 잘 보이는 구간",
            photoURL: uploadedAt == nil ? nil : URL(string: "https://storage.test/read/b.jpg?sig=1"),
            photoUploadedAt: uploadedAt
        )
    }

    private func jpegData() -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    private actor DownloadCounter {
        private(set) var count = 0

        func record() {
            count += 1
        }
    }
}
