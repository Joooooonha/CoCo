package com.coco.server.course;

import java.time.Instant;
import java.util.UUID;

public record CourseElementResponse(
        UUID id,
        UUID courseId,
        ElementCategory category,
        double latitude,
        double longitude,
        int distanceFromStartMeters,
        String title,
        String description,
        /// Absolute URL for reading the photo, or null when there is none.
        /// The storage key is never exposed to clients.
        String photoURL,
        /// When the current photo was uploaded, or null when there is none.
        /// `photoURL` carries a fresh signature on every response, so clients
        /// cache by this instead: it changes only when the photo itself does.
        Instant photoUploadedAt
) {
    static CourseElementResponse from(UUID courseId, CourseElementEntity entity) {
        return from(courseId, entity, null);
    }

    static CourseElementResponse from(UUID courseId, CourseElementEntity entity, String photoURL) {
        return new CourseElementResponse(
                entity.getId(),
                courseId,
                entity.getCategory(),
                entity.getLatitude(),
                entity.getLongitude(),
                entity.getDistanceFromStartMeters(),
                entity.getTitle(),
                entity.getDescription(),
                photoURL,
                entity.getPhotoUploadedAt()
        );
    }
}
