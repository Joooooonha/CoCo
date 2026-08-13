package com.coco.server.user;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ExternalIdentityRepository extends JpaRepository<ExternalIdentityEntity, UUID> {
    @EntityGraph(attributePaths = "user")
    Optional<ExternalIdentityEntity> findByProviderAndProviderUserId(
            AuthProvider provider,
            String providerUserId
    );

    List<ExternalIdentityEntity> findByUserIdOrderByProviderAsc(UUID userId);
}
