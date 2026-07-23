package com.coco.server.user;

import java.util.UUID;

public record UserResponse(UUID id, String displayName, AccountType accountType) {
    public static UserResponse from(UserEntity entity) {
        return new UserResponse(entity.getId(), entity.getDisplayName(), entity.getAccountType());
    }
}
