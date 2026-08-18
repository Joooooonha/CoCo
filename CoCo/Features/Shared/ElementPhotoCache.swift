import Foundation

/// Disk cache for element photos.
///
/// `URLCache` cannot do this job: it keys on the whole URL, and a presigned
/// read URL carries a fresh signature every time the server builds a response,
/// so the same photo would miss on every load. Entries are keyed by the
/// element and its upload time instead, which change only when the photo does.
///
/// Lives in `Library/Caches`, so the system may reclaim it under storage
/// pressure and it never lands in a device backup.
actor ElementPhotoCache {
    static let shared = ElementPhotoCache()

    /// Roughly 150 photos at the size `ElementPhotoProcessor` produces.
    static let defaultCapacityBytes = 80 * 1024 * 1024

    private let directory: URL
    private let capacityBytes: Int
    private let fileManager: FileManager
    private var didPrepareDirectory = false

    init(
        directory: URL? = nil,
        capacityBytes: Int = ElementPhotoCache.defaultCapacityBytes,
        fileManager: FileManager = .default
    ) {
        self.directory = directory ?? fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "ElementPhotos", directoryHint: .isDirectory)
        self.capacityBytes = capacityBytes
        self.fileManager = fileManager
    }

    func data(for key: String) -> Data? {
        let file = location(of: key)
        guard let data = try? Data(contentsOf: file) else { return nil }

        // Eviction is least-recently-used, so a read has to count as use.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return data
    }

    func store(_ data: Data, for key: String) {
        prepareDirectory()
        try? data.write(to: location(of: key), options: .atomic)
        evictIfOverCapacity()
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
        didPrepareDirectory = false
    }

    /// Total bytes currently held. Exposed for tests and diagnostics.
    func currentSizeBytes() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    private func evictIfOverCapacity() {
        var stored = entries()
        var total = stored.reduce(0) { $0 + $1.size }
        guard total > capacityBytes else { return }

        // Drop to a margin below the limit so a run of writes does not trigger
        // a scan every single time.
        let target = capacityBytes * 4 / 5
        stored.sort { $0.lastUsed < $1.lastUsed }

        for entry in stored where total > target {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private func entries() -> [(url: URL, size: Int, lastUsed: Date)] {
        let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        )
        return (contents ?? []).compactMap { url in
            guard let values = try? url.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            ) else {
                return nil
            }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
    }

    private func prepareDirectory() {
        guard !didPrepareDirectory else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        didPrepareDirectory = true
    }

    private func location(of key: String) -> URL {
        directory.appending(path: "\(key).jpg")
    }
}
