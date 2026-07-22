package com.coco.server.auth;

import com.coco.server.user.AccountType;
import java.util.UUID;

public record UserResponse(UUID id, String displayName, AccountType accountType) {
}
