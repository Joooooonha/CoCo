package com.coco.server.course;

import java.util.List;
import java.util.Set;
import java.util.UUID;

public record CourseResponse(
        UUID id,
        UUID ownerId,
        String ownerName,
        String name,
        String summary,
        CourseDifficulty difficulty,
        String locationLabel,
        int distanceMeters,
        int estimatedDurationSeconds,
        RouteSource routeSource,
        List<RoutePointResponse> routePoints,
        List<CourseElementResponse> elements,
        int scrapCount,
        ReactionCountsResponse reactionCounts,
        boolean isScrapped,
        Set<ReactionType> myReactions
) {
    static CourseResponse from(
            CourseEntity entity,
            int scrapCount,
            ReactionCountsResponse reactionCounts,
            boolean isScrapped,
            Set<ReactionType> myReactions
    ) {
        List<RoutePointResponse> routePoints = entity.getRoutePoints().stream()
                .map(RoutePointResponse::from)
                .toList();
        List<CourseElementResponse> elements = entity.getElements().stream()
                .map(element -> CourseElementResponse.from(entity.getId(), element))
                .toList();

        return new CourseResponse(
                entity.getId(),
                entity.getOwner().getId(),
                entity.getOwner().getDisplayName(),
                entity.getName(),
                entity.getSummary(),
                entity.getDifficulty(),
                entity.getLocationLabel(),
                entity.getDistanceMeters(),
                entity.getEstimatedDurationSeconds(),
                entity.getRouteSource(),
                routePoints,
                elements,
                scrapCount,
                reactionCounts,
                isScrapped,
                myReactions
        );
    }
}
