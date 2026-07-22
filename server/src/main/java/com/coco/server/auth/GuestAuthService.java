package com.coco.server.auth;

import com.coco.server.user.AccountType;
import com.coco.server.user.UserEntity;
import com.coco.server.user.UserRepository;
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

@Service
public class GuestAuthService {
    private static final Duration TOKEN_LIFETIME = Duration.ofDays(30);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final AuthTokenRepository authTokenRepository;

    public GuestAuthService(UserRepository userRepository, AuthTokenRepository authTokenRepository) {
        this.userRepository = userRepository;
        this.authTokenRepository = authTokenRepository;
    }

    @Transactional
    public GuestAuthResponse issueGuest() {
        UUID userId = UUID.randomUUID();
        String displayName = "게스트 러너 " + userId.toString().substring(0, 4).toUpperCase();
        UserEntity user = userRepository.save(new UserEntity(userId, displayName, AccountType.GUEST));

        String rawToken = generateToken();
        Instant expiresAt = Instant.now().plus(TOKEN_LIFETIME);
        authTokenRepository.save(
                new AuthTokenEntity(UUID.randomUUID(), user, hash(rawToken), expiresAt)
        );

        return new GuestAuthResponse(
                new UserResponse(user.getId(), user.getDisplayName(), user.getAccountType()),
                rawToken,
                expiresAt
        );
    }

    @Transactional(readOnly = true)
    public Optional<AuthenticatedUser> authenticate(String rawToken) {
        return authTokenRepository
                .findByTokenHashAndRevokedAtIsNullAndExpiresAtAfter(hash(rawToken), Instant.now())
                .map(AuthTokenEntity::getUser)
                .map(user -> new AuthenticatedUser(user.getId(), user.getDisplayName()));
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
