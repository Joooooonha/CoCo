package com.coco.server.course;

import java.util.UUID;

public record RoutePointResponse(UUID id, int sequence, double latitude, double longitude) {
    static RoutePointResponse from(RoutePointEntity entity) {
        return new RoutePointResponse(
                entity.getId(),
                entity.getSequenceNumber(),
                entity.getLatitude(),
                entity.getLongitude()
        );
    }
}
