package com.coco.server.auth.social;

/// The minimum profile CoCo needs from a social provider.
/// `providerUserId` is the provider's stable identifier for the account.
/// `nickname` is only used as the initial display name and may be null.
public record SocialProfile(String providerUserId, String nickname) {
}
