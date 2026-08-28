package com.coco.server.auth;

import com.coco.server.user.UserEntity;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// Issues, authenticates and revokes CoCo bearer tokens.
/// Only SHA-256 hashes are stored; the raw token is returned once at issue time.
@Service
public class AuthTokenService {
    public record IssuedToken(String token, Instant expiresAt) {
    }

    private static final Duration TOKEN_LIFETIME = Duration.ofDays(30);
    /// Skip the write unless the renewal buys at least this much.
    private static final Duration RENEWAL_THRESHOLD = Duration.ofHours(12);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final AuthTokenRepository authTokenRepository;

    public AuthTokenService(AuthTokenRepository authTokenRepository) {
        this.authTokenRepository = authTokenRepository;
    }

    @Transactional
    public IssuedToken issueFor(UserEntity user) {
        String rawToken = generateToken();
        Instant expiresAt = Instant.now().plus(TOKEN_LIFETIME);
        authTokenRepository.save(new AuthTokenEntity(UUID.randomUUID(), user, hash(rawToken), expiresAt));
        return new IssuedToken(rawToken, expiresAt);
    }

    /// Extends the expiry on use. Without this a member who leaves the app
    /// alone for the token lifetime is signed out with nothing to show for it,
    /// even though nothing about their account changed.
    @Transactional
    public Optional<AuthenticatedUser> authenticate(String rawToken) {
        Instant now = Instant.now();
        return authTokenRepository
                .findByTokenHashAndRevokedAtIsNullAndExpiresAtAfter(hash(rawToken), now)
                .map(token -> {
                    // Only write when the gain is meaningful, so ordinary reads
                    // do not turn into a database write each time.
                    Instant renewed = now.plus(TOKEN_LIFETIME);
                    if (renewed.isAfter(token.getExpiresAt().plus(RENEWAL_THRESHOLD))) {
                        token.extendExpiry(renewed);
                    }
                    return token.getUser();
                })
                .map(user -> new AuthenticatedUser(user.getId(), user.getDisplayName()));
    }

    /// Revokes a single token. Used by logout so other devices stay signed in.
    @Transactional
    public void revoke(String rawToken) {
        authTokenRepository.revokeByTokenHash(hash(rawToken), Instant.now());
    }

    @Transactional
    public void revokeAllFor(UUID userId) {
        authTokenRepository.revokeAllForUser(userId, Instant.now());
    }

    private String generateToken() {
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}
