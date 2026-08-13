package com.coco.server.auth;

import com.coco.server.user.AccountType;
import com.coco.server.user.UserEntity;
import com.coco.server.user.UserRepository;
import com.coco.server.user.UserResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GuestAuthService {
    private final UserRepository userRepository;
    private final AuthTokenService authTokenService;

    public GuestAuthService(UserRepository userRepository, AuthTokenService authTokenService) {
        this.userRepository = userRepository;
        this.authTokenService = authTokenService;
    }

    @Transactional
    public AuthResponse issueGuest() {
        UUID userId = UUID.randomUUID();
        String displayName = "게스트 러너 " + userId.toString().substring(0, 4).toUpperCase();
        UserEntity user = userRepository.save(new UserEntity(userId, displayName, AccountType.GUEST));

        AuthTokenService.IssuedToken issued = authTokenService.issueFor(user);
        return new AuthResponse(UserResponse.guest(user), issued.token(), issued.expiresAt());
    }
}
