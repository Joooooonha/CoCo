package com.coco.server.auth;

import java.time.Instant;

public record GuestAuthResponse(UserResponse user, String token, Instant expiresAt) {
}
