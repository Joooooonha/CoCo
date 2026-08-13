package com.coco.server.auth.social;

import com.coco.server.user.AuthProvider;
import java.util.Map;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

/// Naver OAuth 2.0 client.
/// Docs: https://developers.naver.com/docs/login/api/api.md
@Component
public class NaverProviderClient implements SocialProviderClient {
    private static final String AUTHORIZE_URL = "https://nid.naver.com/oauth2.0/authorize";
    private static final String TOKEN_URL = "https://nid.naver.com/oauth2.0/token";
    private static final String PROFILE_URL = "https://openapi.naver.com/v1/nid/me";

    private final RestClient restClient;
    private final SocialLoginProperties properties;

    public NaverProviderClient(RestClient socialRestClient, SocialLoginProperties properties) {
        this.restClient = socialRestClient;
        this.properties = properties;
    }

    @Override
    public AuthProvider provider() {
        return AuthProvider.NAVER;
    }

    @Override
    public String authorizationEndpoint() {
        return AUTHORIZE_URL;
    }

    @Override
    public SocialProfile fetchProfile(String authorizationCode, String redirectUri) {
        var credentials = properties.naver();
        if (credentials == null || !credentials.isConfigured()) {
            throw new SocialProviderException("Naver client credentials are not configured");
        }
        return requestProfile(requestAccessToken(credentials, authorizationCode, redirectUri));
    }

    private String requestAccessToken(
            SocialLoginProperties.ProviderCredentials credentials,
            String authorizationCode,
            String redirectUri
    ) {
        // Naver takes the token request parameters in the query string.
        String tokenUri = UriComponentsBuilder.fromUriString(TOKEN_URL)
                .queryParam("grant_type", "authorization_code")
                .queryParam("client_id", credentials.clientId())
                .queryParam("client_secret", credentials.clientSecret())
                .queryParam("code", authorizationCode)
                .queryParam("redirect_uri", redirectUri)
                .build()
                .toUriString();

        Map<?, ?> body;
        try {
            body = restClient.post().uri(tokenUri).retrieve().body(Map.class);
        } catch (RuntimeException exception) {
            throw new SocialProviderException("Naver token request failed", exception);
        }

        if (body == null || body.get("access_token") == null) {
            throw new SocialProviderException("Naver token response has no access_token");
        }
        return body.get("access_token").toString();
    }

    private SocialProfile requestProfile(String accessToken) {
        Map<?, ?> body;
        try {
            body = restClient.get()
                    .uri(PROFILE_URL)
                    .header("Authorization", "Bearer " + accessToken)
                    .retrieve()
                    .body(Map.class);
        } catch (RuntimeException exception) {
            throw new SocialProviderException("Naver profile request failed", exception);
        }

        if (body == null || !(body.get("response") instanceof Map<?, ?> response)) {
            throw new SocialProviderException("Naver profile response is malformed");
        }

        Object providerUserId = response.get("id");
        if (providerUserId == null || providerUserId.toString().isBlank()) {
            throw new SocialProviderException("Naver profile has no id");
        }

        Object nickname = response.get("nickname");
        return new SocialProfile(providerUserId.toString(), nickname == null ? null : nickname.toString());
    }
}
