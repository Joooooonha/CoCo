import SwiftUI

/// Loads an element photo through `ElementPhotoCache`.
///
/// Deliberately not `AsyncImage`: that goes through `URLCache`, which keys on
/// the presigned URL and would therefore re-download the same photo on every
/// course load.
struct ElementPhotoView: View {
    let element: CourseElement
    var height: CGFloat = 150

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(height: height)
            .overlay {
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            // Swiping between elements reuses this view, so the load has to
            // restart when it is handed a different photo.
            .task(id: element.photoCacheKey) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if didFail {
            placeholder(symbol: "photo.badge.exclamationmark", text: "사진을 불러오지 못했어요")
        } else if element.hasPhoto {
            ProgressView()
        } else {
            placeholder(symbol: "photo.on.rectangle.angled", text: "등록된 사진이 없어요")
        }
    }

    private func placeholder(symbol: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityLabel: String {
        if image != nil {
            return "\(element.title) 사진"
        }
        if didFail {
            return "\(element.title) 사진을 불러오지 못했습니다"
        }
        return element.hasPhoto ? "\(element.title) 사진 불러오는 중" : "등록된 사진 없음"
    }

    private func load() async {
        image = nil
        didFail = false
        guard element.hasPhoto else { return }

        let loaded = await ElementPhotoLoader.shared.image(for: element)
        guard !Task.isCancelled else { return }

        image = loaded
        didFail = loaded == nil
    }
}

/// Reads an element photo from the cache, falling back to the presigned URL.
@MainActor
struct ElementPhotoLoader {
    static let shared = ElementPhotoLoader()

    var cache: ElementPhotoCache = .shared
    var fetch: (URL) async throws -> Data = { url in
        try await CourseAPIClient().fetchPhotoData(from: url)
    }

    func image(for element: CourseElement) async -> UIImage? {
        guard let key = element.photoCacheKey, let url = element.photoURL else { return nil }
        return await image(cacheKey: key, url: url)
    }

    func image(cacheKey key: String, url: URL) async -> UIImage? {
        if let cached = await cache.data(for: key) {
            return UIImage(data: cached)
        }

        guard let downloaded = try? await fetch(url), let image = UIImage(data: downloaded) else {
            return nil
        }
        // Only store what actually decoded, so a truncated download does not
        // become a permanently broken cache entry.
        await cache.store(downloaded, for: key)
        return image
    }
}
