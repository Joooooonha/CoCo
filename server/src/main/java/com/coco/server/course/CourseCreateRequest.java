package com.coco.server.course;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.util.List;

public record CourseCreateRequest(
        @NotBlank @Size(max = 100) String name,
        @NotBlank @Size(max = 255) String summary,
        @NotNull CourseDifficulty difficulty,
        @Size(max = 120) String locationLabel,
        @NotNull @Positive @Max(200_000) Integer distanceMeters,
        @NotNull @Positive @Max(86_400) Integer estimatedDurationSeconds,
        @NotNull RouteSource routeSource,
        @NotNull @Size(min = 2, max = 2_000) @Valid List<RoutePointCreateRequest> routePoints,
        @NotNull @Size(min = 1, max = 50) @Valid List<ElementCreateRequest> elements
) {
    public record RoutePointCreateRequest(
            @NotNull @Min(0) Integer sequence,
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude
    ) {
    }
}
