package com.coco.server.course;

import com.coco.server.common.BadRequestException;
import com.coco.server.common.ConflictException;
import com.coco.server.common.ForbiddenOperationException;
import com.coco.server.common.ResourceNotFoundException;
import com.coco.server.common.PayloadTooLargeException;
import com.coco.server.storage.ObjectStorage;
import com.coco.server.storage.StorageUnavailableException;
import java.time.Duration;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// Handles element photos without ever touching the image bytes. The server
/// checks ownership and limits, then hands out a presigned URL so the client
/// uploads straight to storage.
@Service
public class ElementPhotoService {
    private static final Logger LOGGER = LoggerFactory.getLogger(ElementPhotoService.class);

    public record UploadTicket(String uploadURL, String contentType, long maxContentLength) {
    }

    static final Duration UPLOAD_VALIDITY = Duration.ofMinutes(5);
    static final Duration DOWNLOAD_VALIDITY = Duration.ofHours(1);
    static final long MAXIMUM_PHOTO_BYTES = 5L * 1024 * 1024;
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of("image/jpeg", "image/heic");

    private final CourseElementRepository courseElementRepository;
    private final CourseRepository courseRepository;
    private final ObjectStorage objectStorage;

    public ElementPhotoService(
            CourseElementRepository courseElementRepository,
            CourseRepository courseRepository,
            ObjectStorage objectStorage
    ) {
        this.courseElementRepository = courseElementRepository;
        this.courseRepository = courseRepository;
        this.objectStorage = objectStorage;
    }

    @Transactional(readOnly = true)
    public UploadTicket createUploadTicket(
            UUID userId,
            UUID courseId,
            UUID elementId,
            String contentType,
            long contentLength
    ) {
        if (!ALLOWED_CONTENT_TYPES.contains(contentType)) {
            throw new BadRequestException(
                    "PHOTO_CONTENT_TYPE_UNSUPPORTED",
                    "JPEG 또는 HEIC 사진만 올릴 수 있어요."
            );
        }
        if (contentLength <= 0 || contentLength > MAXIMUM_PHOTO_BYTES) {
            throw new PayloadTooLargeException("PHOTO_TOO_LARGE", "사진은 5 MiB 이하만 올릴 수 있어요.");
        }

        CourseElementEntity element = requireOwnedElement(userId, courseId, elementId);
        String objectKey = objectKey(courseId, element.getId(), contentType);

        return new UploadTicket(
                objectStorage.presignedUpload(objectKey, contentType, contentLength, UPLOAD_VALIDITY).toString(),
                contentType,
                MAXIMUM_PHOTO_BYTES
        );
    }

    /// Confirms an upload the client says it finished. The object has to exist
    /// and stay within the size limit, so a ticket cannot be used to attach
    /// something the server never approved.
    @Transactional
    public CourseElementResponse confirmUpload(
            UUID userId,
            UUID courseId,
            UUID elementId,
            String contentType
    ) {
        CourseElementEntity element = requireOwnedElement(userId, courseId, elementId);
        String objectKey = objectKey(courseId, element.getId(), contentType);

        long uploadedBytes = objectStorage.contentLength(objectKey).orElseThrow(() ->
                new ConflictException("PHOTO_NOT_UPLOADED", "사진 업로드가 완료되지 않았어요.")
        );
        if (uploadedBytes > MAXIMUM_PHOTO_BYTES) {
            objectStorage.delete(objectKey);
            throw new PayloadTooLargeException("PHOTO_TOO_LARGE", "사진은 5 MiB 이하만 올릴 수 있어요.");
        }

        String previousKey = element.getPhotoObjectKey();
        element.attachPhoto(objectKey, Instant.now());
        // Replacing a photo of a different format leaves the old object behind.
        if (previousKey != null && !previousKey.equals(objectKey)) {
            objectStorage.delete(previousKey);
        }

        return CourseElementResponse.from(courseId, element, readableURL(objectKey));
    }

    @Transactional
    public void deletePhoto(UUID userId, UUID courseId, UUID elementId) {
        CourseElementEntity element = requireOwnedElement(userId, courseId, elementId);
        String objectKey = element.getPhotoObjectKey();
        if (objectKey == null) {
            return;
        }

        element.detachPhoto();
        objectStorage.delete(objectKey);
    }

    /// Null-safe so response mapping can call it for every element. If storage
    /// disappears while rows still point at objects, course reads keep working
    /// and only the photos go missing.
    public String readableURL(String objectKey) {
        if (objectKey == null) {
            return null;
        }
        try {
            return objectStorage.presignedDownload(objectKey, DOWNLOAD_VALIDITY).toString();
        } catch (StorageUnavailableException exception) {
            LOGGER.warn("Photo URLs are unavailable because object storage is not configured");
            return null;
        }
    }

    /// Removes stored objects for elements that are about to disappear.
    public void deleteStoredPhotos(Iterable<CourseElementEntity> elements) {
        for (CourseElementEntity element : elements) {
            String objectKey = element.getPhotoObjectKey();
            if (objectKey != null) {
                objectStorage.delete(objectKey);
            }
        }
    }

    /// The key carries no user identifier and stays stable per element and format.
    private String objectKey(UUID courseId, UUID elementId, String contentType) {
        String extension = "image/heic".equals(contentType) ? "heic" : "jpg";
        return "courses/%s/elements/%s.%s".formatted(courseId, elementId, extension);
    }

    private CourseElementEntity requireOwnedElement(UUID userId, UUID courseId, UUID elementId) {
        if (!courseRepository.existsById(courseId)) {
            throw new ResourceNotFoundException("COURSE_NOT_FOUND", "코스를 찾을 수 없습니다.");
        }
        CourseElementEntity element = courseElementRepository.findByIdAndCourseId(elementId, courseId)
                .orElseThrow(() -> new ResourceNotFoundException("ELEMENT_NOT_FOUND", "코스 요소를 찾을 수 없습니다."));

        if (!element.getCourse().getOwner().getId().equals(userId)) {
            throw new ForbiddenOperationException("COURSE_OWNER_ONLY", "코스 작성자만 사진을 관리할 수 있습니다.");
        }
        return element;
    }
}
