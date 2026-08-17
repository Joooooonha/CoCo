package com.coco.server.api;

import com.coco.server.storage.ObjectStorage;
import java.net.URI;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/// Stands in for R2 in tests. It records sizes rather than bytes, which is all
/// the server ever asks storage about.
class InMemoryObjectStorage implements ObjectStorage {
    private final Map<String, Long> sizesByKey = new ConcurrentHashMap<>();

    @Override
    public URI presignedUpload(String objectKey, String contentType, long contentLength, Duration validity) {
        return URI.create("https://storage.test/upload/" + objectKey + "?expires=" + validity.toSeconds());
    }

    @Override
    public URI presignedDownload(String objectKey, Duration validity) {
        return URI.create("https://storage.test/read/" + objectKey + "?expires=" + validity.toSeconds());
    }

    @Override
    public Optional<Long> contentLength(String objectKey) {
        return Optional.ofNullable(sizesByKey.get(objectKey));
    }

    @Override
    public void delete(String objectKey) {
        sizesByKey.remove(objectKey);
    }

    /// Simulates the client finishing its upload against the presigned URL.
    void put(String objectKey, long contentLength) {
        sizesByKey.put(objectKey, contentLength);
    }

    boolean contains(String objectKey) {
        return sizesByKey.containsKey(objectKey);
    }

    void clear() {
        sizesByKey.clear();
    }
}
