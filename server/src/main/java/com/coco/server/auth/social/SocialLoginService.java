package com.coco.server.auth.social;

import com.coco.server.auth.AuthResponse;
import com.coco.server.auth.AuthTokenService;
import com.coco.server.common.BadRequestException;
import com.coco.server.user.AccountType;
import com.coco.server.user.AuthProvider;
import com.coco.server.user.ExternalIdentityEntity;
import com.coco.server.user.ExternalIdentityRepository;
import com.coco.server.user.UserEntity;
import com.coco.server.user.UserRepository;
import com.coco.server.user.UserService;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SocialLoginService {
    private final Map<AuthProvider, SocialProviderClient> clients;
    private final SocialLoginProperties properties;
    private final UserRepository userRepository;
    private final ExternalIdentityRepository externalIdentityRepository;
    private final AuthTokenService authTokenService;
    private final UserService userService;

    public SocialLoginService(
            List<SocialProviderClient> providerClients,
            SocialLoginProperties properties,
            UserRepository userRepository,
            ExternalIdentityRepository externalIdentityRepository,
            AuthTokenService authTokenService,
            UserService userService
    ) {
        this.clients = providerClients.stream()
                .collect(java.util.stream.Collectors.toMap(SocialProviderClient::provider, Function.identity()));
        this.properties = properties;
        this.userRepository = userRepository;
        this.externalIdentityRepository = externalIdentityRepository;
        this.authTokenService = authTokenService;
        this.userService = userService;
    }

    /// Exchanges an authorization code and resolves the account it belongs to.
    /// `currentUserId` is the caller's guest account when one was presented.
    @Transactional
    public AuthResponse login(
            AuthProvider provider,
            String authorizationCode,
            String redirectUri,
            UUID currentUserId
    ) {
        if (!properties.allows(redirectUri)) {
            throw new BadRequestException(
                    "AUTH_REDIRECT_URI_MISMATCH",
                    "허용되지 않은 리디렉션 주소입니다."
            );
        }

        SocialProviderClient client = clients.get(provider);
        if (client == null) {
            throw new BadRequestException("AUTH_PROVIDER_UNSUPPORTED", "지원하지 않는 로그인 제공자입니다.");
        }

        SocialProfile profile = client.fetchProfile(authorizationCode, redirectUri);
        UserEntity user = resolveAccount(provider, profile, currentUserId);

        // The guest token that authorized this call is replaced by the new one.
        if (currentUserId != null) {
            authTokenService.revokeAllFor(currentUserId);
        }
        AuthTokenService.IssuedToken issued = authTokenService.issueFor(user);
        return new AuthResponse(userService.describe(user), issued.token(), issued.expiresAt());
    }

    private UserEntity resolveAccount(AuthProvider provider, SocialProfile profile, UUID currentUserId) {
        Optional<ExternalIdentityEntity> existing = externalIdentityRepository
                .findByProviderAndProviderUserId(provider, profile.providerUserId());

        // Already linked: log into that account without merging guest data.
        if (existing.isPresent()) {
            return existing.get().getUser();
        }

        // Unlinked identity plus a live guest: promote the guest in place so
        // its scraps, reactions and courses carry over.
        if (currentUserId != null) {
            Optional<UserEntity> guest = userRepository.findById(currentUserId);
            if (guest.isPresent() && guest.get().getAccountType() == AccountType.GUEST) {
                UserEntity promoted = guest.get();
                promoted.promoteToMember();
                link(promoted, provider, profile);
                return promoted;
            }
        }

        return link(createMember(profile), provider, profile);
    }

    private UserEntity createMember(SocialProfile profile) {
        UUID userId = UUID.randomUUID();
        String displayName = resolveDisplayName(profile, userId);
        return userRepository.save(new UserEntity(userId, displayName, AccountType.MEMBER));
    }

    private UserEntity link(UserEntity user, AuthProvider provider, SocialProfile profile) {
        externalIdentityRepository.save(
                new ExternalIdentityEntity(UUID.randomUUID(), user, provider, profile.providerUserId())
        );
        return user;
    }

    /// The provider nickname seeds the display name only for brand new accounts.
    /// A promoted guest keeps whatever name it already had.
    private String resolveDisplayName(SocialProfile profile, UUID userId) {
        String nickname = profile.nickname();
        if (nickname != null && !nickname.isBlank()) {
            String trimmed = nickname.strip();
            return trimmed.length() > 20 ? trimmed.substring(0, 20) : trimmed;
        }
        return "러너 " + userId.toString().substring(0, 4).toUpperCase();
    }
}
