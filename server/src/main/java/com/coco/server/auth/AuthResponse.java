package com.coco.server.auth;

import com.coco.server.user.UserResponse;
import java.time.Instant;

/// Returned by every path that issues a CoCo token: guest creation and social login.
public record AuthResponse(UserResponse user, String token, Instant expiresAt) {
}
