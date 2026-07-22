package com.coco.server.common;

import java.time.Instant;

public record ApiErrorResponse(int status, String code, String message, Instant timestamp) {
    public static ApiErrorResponse of(int status, String code, String message) {
        return new ApiErrorResponse(status, code, message, Instant.now());
    }
}
