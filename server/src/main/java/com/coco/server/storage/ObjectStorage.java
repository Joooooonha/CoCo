package com.coco.server.storage;

import java.net.URI;
import java.time.Duration;
import java.util.Optional;

/// Object storage for user media.
///
/// Image bytes never pass through this server: clients upload straight to the
/// storage with a presigned URL and read back through another one. Cloudflare R2
/// and AWS S3 both speak the S3 API, so only endpoint and credentials differ.
public interface ObjectStorage {
    URI presignedUpload(String objectKey, String contentType, long contentLength, Duration validity);

    URI presignedDownload(String objectKey, Duration validity);

    /// Size of the stored object, or empty when it does not exist. Used to
    /// confirm that a client actually completed its upload.
    Optional<Long> contentLength(String objectKey);

    void delete(String objectKey);
}
