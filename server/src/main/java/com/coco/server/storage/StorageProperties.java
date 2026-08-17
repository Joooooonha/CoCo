package com.coco.server.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/// Object storage configuration. Credentials come from the environment and are
/// never committed; see `.env.production.example` for the variable names.
@ConfigurationProperties(prefix = "coco.storage")
public record StorageProperties(
        /// S3-compatible endpoint. For R2 this is `https://<account-id>.r2.cloudflarestorage.com`.
        String endpoint,
        /// R2 ignores the region but the S3 client requires one to be set.
        String region,
        String bucket,
        String accessKeyId,
        String secretAccessKey
) {
    public boolean isConfigured() {
        return endpoint != null && !endpoint.isBlank()
                && bucket != null && !bucket.isBlank()
                && accessKeyId != null && !accessKeyId.isBlank()
                && secretAccessKey != null && !secretAccessKey.isBlank();
    }
}
