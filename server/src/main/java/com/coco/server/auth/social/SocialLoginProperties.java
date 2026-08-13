package com.coco.server.auth.social;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/// Social login configuration. Secrets are injected from the environment and
/// never committed; see `.env.production.example` for the variable names.
@ConfigurationProperties(prefix = "coco.social")
public record SocialLoginProperties(
        /// The custom scheme URL the server redirects to after the provider callback.
        String appCallbackUrl,
        /// Redirect URIs the client is allowed to request, matched exactly.
        List<String> allowedRedirectUris,
        ProviderCredentials naver,
        ProviderCredentials kakao
) {
    public record ProviderCredentials(String clientId, String clientSecret) {
        public boolean isConfigured() {
            return clientId != null && !clientId.isBlank();
        }
    }

    public boolean allows(String redirectUri) {
        return allowedRedirectUris != null && allowedRedirectUris.contains(redirectUri);
    }
}
