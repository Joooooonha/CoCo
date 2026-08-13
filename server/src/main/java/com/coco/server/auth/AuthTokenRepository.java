package com.coco.server.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AuthTokenRepository extends JpaRepository<AuthTokenEntity, UUID> {
    @EntityGraph(attributePaths = "user")
    Optional<AuthTokenEntity> findByTokenHashAndRevokedAtIsNullAndExpiresAtAfter(
            String tokenHash,
            Instant now
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update AuthTokenEntity token
            set token.revokedAt = :now
            where token.tokenHash = :tokenHash and token.revokedAt is null
            """)
    int revokeByTokenHash(@Param("tokenHash") String tokenHash, @Param("now") Instant now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update AuthTokenEntity token
            set token.revokedAt = :now
            where token.user.id = :userId and token.revokedAt is null
            """)
    int revokeAllForUser(@Param("userId") UUID userId, @Param("now") Instant now);
}
