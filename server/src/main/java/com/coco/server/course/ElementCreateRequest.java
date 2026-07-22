package com.coco.server.course;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ElementCreateRequest(
        @NotNull ElementCategory category,
        @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
        @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude,
        @NotNull @Min(0) Integer distanceFromStartMeters,
        @NotBlank @Size(max = 100) String title,
        @NotBlank @Size(max = 500) String description
) {
}
