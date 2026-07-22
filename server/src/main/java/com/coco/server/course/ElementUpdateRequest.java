package com.coco.server.course;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record ElementUpdateRequest(
        ElementCategory category,
        @DecimalMin("-90") @DecimalMax("90") Double latitude,
        @DecimalMin("-180") @DecimalMax("180") Double longitude,
        @Min(0) Integer distanceFromStartMeters,
        @Size(min = 1, max = 100) String title,
        @Size(min = 1, max = 500) String description
) {
}
