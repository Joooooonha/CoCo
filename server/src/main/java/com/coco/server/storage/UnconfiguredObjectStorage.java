package com.coco.server.storage;

import java.net.URI;
import java.time.Duration;
import java.util.Optional;

/// Stands in when no storage credentials are set, so the rest of the API keeps
/// working and photo endpoints fail with a clear reason.
public class UnconfiguredObjectStorage implements ObjectStorage {
    @Override
    public URI presignedUpload(String objectKey, String contentType, long contentLength, Duration validity) {
        throw new StorageUnavailableException();
    }

    @Override
    public URI presignedDownload(String objectKey, Duration validity) {
        throw new StorageUnavailableException();
    }

    @Override
    public Optional<Long> contentLength(String objectKey) {
        throw new StorageUnavailableException();
    }

    @Override
    public void delete(String objectKey) {
        throw new StorageUnavailableException();
    }
}
