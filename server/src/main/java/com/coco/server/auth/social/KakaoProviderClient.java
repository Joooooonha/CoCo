package com.coco.server.auth.social;

import com.coco.server.user.AuthProvider;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

/// Kakao OAuth 2.0 client.
/// Docs: https://developers.kakao.com/docs/latest/ko/kakaologin/rest-api
@Component
public class KakaoProviderClient implements SocialProviderClient {
    private static final String AUTHORIZE_URL = "https://kauth.kakao.com/oauth/authorize";
    private static final String TOKEN_URL = "https://kauth.kakao.com/oauth/token";
    private static final String PROFILE_URL = "https://kapi.kakao.com/v2/user/me";

    private final RestClient restClient;
    private final SocialLoginProperties properties;

    public KakaoProviderClient(RestClient socialRestClient, SocialLoginProperties properties) {
        this.restClient = socialRestClient;
        this.properties = properties;
    }

    @Override
    public AuthProvider provider() {
        return AuthProvider.KAKAO;
    }

    @Override
    public String authorizationEndpoint() {
        return AUTHORIZE_URL;
    }

    @Override
    public SocialProfile fetchProfile(String authorizationCode, String redirectUri) {
        var credentials = properties.kakao();
        if (credentials == null || !credentials.isConfigured()) {
            throw new SocialProviderException("Kakao client credentials are not configured");
        }
        return requestProfile(requestAccessToken(credentials, authorizationCode, redirectUri));
    }

    private String requestAccessToken(
            SocialLoginProperties.ProviderCredentials credentials,
            String authorizationCode,
            String redirectUri
    ) {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "authorization_code");
        form.add("client_id", credentials.clientId());
        form.add("redirect_uri", redirectUri);
        form.add("code", authorizationCode);
        if (credentials.clientSecret() != null && !credentials.clientSecret().isBlank()) {
            form.add("client_secret", credentials.clientSecret());
        }

        Map<?, ?> body;
        try {
            body = restClient.post()
                    .uri(TOKEN_URL)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .body(Map.class);
        } catch (RuntimeException exception) {
            throw new SocialProviderException("Kakao token request failed", exception);
        }

        if (body == null || body.get("access_token") == null) {
            throw new SocialProviderException("Kakao token response has no access_token");
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
            throw new SocialProviderException("Kakao profile request failed", exception);
        }

        if (body == null || body.get("id") == null) {
            throw new SocialProviderException("Kakao profile has no id");
        }

        return new SocialProfile(body.get("id").toString(), extractNickname(body));
    }

    /// Nickname lives under `properties.nickname`, which is absent when the
    /// user declines the profile consent item.
    private String extractNickname(Map<?, ?> body) {
        if (body.get("properties") instanceof Map<?, ?> profileProperties) {
            Object nickname = profileProperties.get("nickname");
            if (nickname != null && !nickname.toString().isBlank()) {
                return nickname.toString();
            }
        }
        return null;
    }
}
