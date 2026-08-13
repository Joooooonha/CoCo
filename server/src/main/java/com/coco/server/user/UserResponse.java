package com.coco.server.user;

import java.util.List;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String displayName,
        AccountType accountType,
        List<AuthProvider> linkedProviders
) {
    public static UserResponse of(UserEntity user, List<AuthProvider> linkedProviders) {
        return new UserResponse(
                user.getId(),
                user.getDisplayName(),
                user.getAccountType(),
                List.copyOf(linkedProviders)
        );
    }

    public static UserResponse guest(UserEntity user) {
        return of(user, List.of());
    }
}
