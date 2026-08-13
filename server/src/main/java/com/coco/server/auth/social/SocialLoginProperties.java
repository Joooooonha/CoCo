package com.coco.server.auth.social;

import com.coco.server.user.AuthProvider;
import org.springframework.boot.context.properties.ConfigurationProperties;

/// Social login configuration. Secrets are injected from the environment and
/// never committed; see `.env.production.example` for the variable names.
@ConfigurationProperties(prefix = "coco.social")
public record SocialLoginProperties(
        /// The custom scheme URL the server redirects to after the provider callback.
        String appCallbackUrl,
        ProviderCredentials naver,
        ProviderCredentials kakao
) {
    public record ProviderCredentials(String clientId, String clientSecret, String redirectUri) {
        public boolean isConfigured() {
            return clientId != null && !clientId.isBlank();
        }
    }

    public ProviderCredentials credentialsFor(AuthProvider provider) {
        return switch (provider) {
            case NAVER -> naver;
            case KAKAO -> kakao;
        };
    }
}
