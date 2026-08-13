package com.coco.server.user;

import com.coco.server.common.ResourceNotFoundException;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {
    private final UserRepository userRepository;
    private final ExternalIdentityRepository externalIdentityRepository;

    public UserService(
            UserRepository userRepository,
            ExternalIdentityRepository externalIdentityRepository
    ) {
        this.userRepository = userRepository;
        this.externalIdentityRepository = externalIdentityRepository;
    }

    @Transactional(readOnly = true)
    public UserResponse findById(UUID userId) {
        return describe(requireUser(userId));
    }

    @Transactional
    public UserResponse updateDisplayName(UUID userId, String displayName) {
        UserEntity user = requireUser(userId);
        user.rename(displayName.strip());
        return describe(user);
    }

    /// Builds the API view of a user together with the providers linked to it.
    @Transactional(readOnly = true)
    public UserResponse describe(UserEntity user) {
        List<AuthProvider> providers = externalIdentityRepository
                .findByUserIdOrderByProviderAsc(user.getId())
                .stream()
                .map(ExternalIdentityEntity::getProvider)
                .toList();
        return UserResponse.of(user, providers);
    }

    private UserEntity requireUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("USER_NOT_FOUND", "사용자를 찾을 수 없습니다."));
    }
}
