package com.coco.server.course;

import java.util.UUID;

public record CourseElementResponse(
        UUID id,
        UUID courseId,
        ElementCategory category,
        double latitude,
        double longitude,
        int distanceFromStartMeters,
        String title,
        String description
) {
    static CourseElementResponse from(UUID courseId, CourseElementEntity entity) {
        return new CourseElementResponse(
                entity.getId(),
                courseId,
                entity.getCategory(),
                entity.getLatitude(),
                entity.getLongitude(),
                entity.getDistanceFromStartMeters(),
                entity.getTitle(),
                entity.getDescription()
        );
    }
}
