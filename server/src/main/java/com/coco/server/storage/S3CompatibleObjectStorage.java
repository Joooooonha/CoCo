package com.coco.server.storage;

import java.net.URI;
import java.time.Duration;
import java.util.Optional;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

/// Talks to any S3-compatible storage. Used with Cloudflare R2 today and ready
/// for AWS S3 with a different endpoint and credentials.
public class S3CompatibleObjectStorage implements ObjectStorage {
    private final S3Client client;
    private final S3Presigner presigner;
    private final String bucket;

    public S3CompatibleObjectStorage(StorageProperties properties) {
        var credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(properties.accessKeyId(), properties.secretAccessKey())
        );
        var region = Region.of(properties.region() == null ? "auto" : properties.region());
        var endpoint = URI.create(properties.endpoint());
        // R2 does not support virtual-host style addressing for these buckets.
        var serviceConfiguration = S3Configuration.builder().pathStyleAccessEnabled(true).build();

        this.client = S3Client.builder()
                .endpointOverride(endpoint)
                .region(region)
                .credentialsProvider(credentials)
                .serviceConfiguration(serviceConfiguration)
                .build();
        this.presigner = S3Presigner.builder()
                .endpointOverride(endpoint)
                .region(region)
                .credentialsProvider(credentials)
                .serviceConfiguration(serviceConfiguration)
                .build();
        this.bucket = properties.bucket();
    }

    @Override
    public URI presignedUpload(String objectKey, String contentType, long contentLength, Duration validity) {
        // Content type and length are signed, so the client cannot upload a
        // different kind or a larger file than the server approved.
        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucket)
                .key(objectKey)
                .contentType(contentType)
                .contentLength(contentLength)
                .build();

        return URI.create(
                presigner.presignPutObject(
                        PutObjectPresignRequest.builder()
                                .signatureDuration(validity)
                                .putObjectRequest(putRequest)
                                .build()
                ).url().toString()
        );
    }

    @Override
    public URI presignedDownload(String objectKey, Duration validity) {
        GetObjectRequest getRequest = GetObjectRequest.builder()
                .bucket(bucket)
                .key(objectKey)
                .build();

        return URI.create(
                presigner.presignGetObject(
                        GetObjectPresignRequest.builder()
                                .signatureDuration(validity)
                                .getObjectRequest(getRequest)
                                .build()
                ).url().toString()
        );
    }

    @Override
    public Optional<Long> contentLength(String objectKey) {
        try {
            var head = client.headObject(
                    HeadObjectRequest.builder().bucket(bucket).key(objectKey).build()
            );
            return Optional.ofNullable(head.contentLength());
        } catch (NoSuchKeyException exception) {
            return Optional.empty();
        } catch (S3Exception exception) {
            // Some S3-compatible services answer a missing key with a plain 404.
            if (exception.statusCode() == 404) {
                return Optional.empty();
            }
            throw exception;
        }
    }

    @Override
    public void delete(String objectKey) {
        client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(objectKey).build());
    }
}
