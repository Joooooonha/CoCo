package com.coco.server.storage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import org.junit.jupiter.api.Test;

/// Presigning is local math, so these run without touching a real bucket.
class S3CompatibleObjectStorageTest {
    private static final StorageProperties PROPERTIES = new StorageProperties(
            "https://example.r2.cloudflarestorage.com",
            "auto",
            "coco-element-photos",
            "access-key-id",
            "secret-access-key"
    );

    /// The size limit only holds if the client cannot swap in a different file,
    /// so both the type and the length have to be part of the signature.
    @Test
    void uploadURLSignsTheContentTypeAndLength() {
        var storage = new S3CompatibleObjectStorage(PROPERTIES);

        String url = storage.presignedUpload("courses/a/elements/b.jpg", "image/jpeg", 102_400, Duration.ofMinutes(5))
                .toString();

        assertTrue(url.contains("X-Amz-SignedHeaders=content-length%3Bcontent-type%3Bhost"), url);
        assertTrue(url.contains("X-Amz-Expires=300"), url);
    }

    /// R2 buckets are not reachable as `<bucket>.<host>`, so the bucket has to
    /// stay in the path.
    @Test
    void urlsUsePathStyleAddressingAndExpire() {
        var storage = new S3CompatibleObjectStorage(PROPERTIES);

        String url = storage.presignedDownload("courses/a/elements/b.jpg", Duration.ofHours(1)).toString();

        assertTrue(
                url.startsWith("https://example.r2.cloudflarestorage.com/coco-element-photos/courses/a/elements/b.jpg"),
                url
        );
        assertTrue(url.contains("X-Amz-Expires=3600"), url);
    }

    @Test
    void blankCredentialsCountAsUnconfigured() {
        assertTrue(PROPERTIES.isConfigured());
        assertEquals(false, new StorageProperties("https://example", "auto", "bucket", "", "secret").isConfigured());
        assertEquals(false, new StorageProperties(null, "auto", "bucket", "key", "secret").isConfigured());
    }

    @Test
    void unconfiguredStorageRefusesEveryCall() {
        var storage = new UnconfiguredObjectStorage();

        assertThrows(StorageUnavailableException.class, () ->
                storage.presignedUpload("key", "image/jpeg", 1, Duration.ofMinutes(5)));
        assertThrows(StorageUnavailableException.class, () -> storage.presignedDownload("key", Duration.ofHours(1)));
        assertThrows(StorageUnavailableException.class, () -> storage.contentLength("key"));
        assertThrows(StorageUnavailableException.class, () -> storage.delete("key"));
    }
}
