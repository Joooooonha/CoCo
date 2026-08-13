package com.coco.server.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.coco.server.auth.social.SocialProfile;
import com.coco.server.auth.social.SocialProviderClient;
import com.coco.server.auth.social.SocialProviderException;
import com.coco.server.user.AuthProvider;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.ObjectMapper;

/// Covers the account decision rules of social login without contacting the real
/// providers. The provider clients are replaced by stubs that map an authorization
/// code to a fixed profile, so the OAuth transport is out of scope here while the
/// account linking, guest migration and deletion behaviour is fully exercised.
@SpringBootTest(properties = "spring.main.allow-bean-definition-overriding=true")
@AutoConfigureMockMvc
@Testcontainers
class SocialLoginIntegrationTest {
    private static final String REDIRECT_URI =
            "http://localhost:8080/api/v1/auth/social/naver/callback";
    private static final String KAKAO_REDIRECT_URI =
            "http://localhost:8080/api/v1/auth/social/kakao/callback";

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

    /// Maps authorization code to the profile the stubbed provider returns.
    static final Map<String, SocialProfile> PROFILES = new HashMap<>();

    /// Replaces the real provider beans by name so the injected client list holds
    /// exactly one client per provider.
    @TestConfiguration
    static class StubProviders {
        @Bean("naverProviderClient")
        SocialProviderClient stubNaver() {
            return stubFor(AuthProvider.NAVER);
        }

        @Bean("kakaoProviderClient")
        SocialProviderClient stubKakao() {
            return stubFor(AuthProvider.KAKAO);
        }

        private static SocialProviderClient stubFor(AuthProvider provider) {
            return new SocialProviderClient() {
                @Override
                public AuthProvider provider() {
                    return provider;
                }

                @Override
                public String authorizationEndpoint() {
                    return "https://example.test/authorize";
                }

                @Override
                public SocialProfile fetchProfile(String authorizationCode, String redirectUri) {
                    SocialProfile profile = PROFILES.get(provider + ":" + authorizationCode);
                    if (profile == null) {
                        throw new SocialProviderException("unknown code");
                    }
                    return profile;
                }
            };
        }
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void resetProfiles() {
        PROFILES.clear();
    }

    @Test
    void guestKeepsItsDataWhenLinkingFirstSocialAccount() throws Exception {
        String providerUserId = "naver-" + UUID.randomUUID();
        PROFILES.put("NAVER:code-1", new SocialProfile(providerUserId, "노을러너"));

        String guestBody = issueGuest();
        String guestToken = readToken(guestBody);
        String guestUserId = objectMapper.readTree(guestBody).get("user").get("id").asText();

        mockMvc.perform(post("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + guestToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(courseJson("승계 확인 코스")))
                .andExpect(status().isCreated());

        String loginBody = mockMvc.perform(post("/api/v1/auth/social/naver")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + guestToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-1", REDIRECT_URI)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(guestUserId))
                .andExpect(jsonPath("$.user.accountType").value("MEMBER"))
                .andExpect(jsonPath("$.user.linkedProviders[0]").value("NAVER"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        // The promoted account keeps the name and the course it had as a guest.
        String memberToken = readToken(loginBody);
        mockMvc.perform(get("/api/v1/me/courses").header(HttpHeaders.AUTHORIZATION, "Bearer " + memberToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].name").value("승계 확인 코스"));

        // The guest token that authorized the upgrade is no longer usable.
        mockMvc.perform(get("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + guestToken))
                .andExpect(status().isUnauthorized());

        deleteAccount(memberToken);
    }

    @Test
    void loginWithoutGuestTokenCreatesNewMember() throws Exception {
        PROFILES.put("KAKAO:code-2", new SocialProfile("kakao-" + UUID.randomUUID(), "숲길메이트"));

        String body = mockMvc.perform(post("/api/v1/auth/social/kakao")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-2", KAKAO_REDIRECT_URI)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.accountType").value("MEMBER"))
                .andExpect(jsonPath("$.user.displayName").value("숲길메이트"))
                .andExpect(jsonPath("$.user.linkedProviders[0]").value("KAKAO"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        deleteAccount(readToken(body));
    }

    @Test
    void secondLoginReturnsToTheSameAccount() throws Exception {
        String providerUserId = "naver-" + UUID.randomUUID();
        PROFILES.put("NAVER:code-3", new SocialProfile(providerUserId, "재방문러너"));

        String first = mockMvc.perform(post("/api/v1/auth/social/naver")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-3", REDIRECT_URI)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String userId = objectMapper.readTree(first).get("user").get("id").asText();

        String second = mockMvc.perform(post("/api/v1/auth/social/naver")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-3", REDIRECT_URI)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(userId))
                .andReturn()
                .getResponse()
                .getContentAsString();

        deleteAccount(readToken(second));
    }

    @Test
    void alreadyLinkedIdentityDoesNotAbsorbGuestData() throws Exception {
        String providerUserId = "naver-" + UUID.randomUUID();
        PROFILES.put("NAVER:code-4", new SocialProfile(providerUserId, "기존회원"));

        String existing = mockMvc.perform(post("/api/v1/auth/social/naver")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-4", REDIRECT_URI)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String existingUserId = objectMapper.readTree(existing).get("user").get("id").asText();

        // A fresh guest logs in with an identity that already belongs to someone.
        String guestToken = readToken(issueGuest());
        String loginBody = mockMvc.perform(post("/api/v1/auth/social/naver")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + guestToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-4", REDIRECT_URI)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(existingUserId))
                .andReturn()
                .getResponse()
                .getContentAsString();

        deleteAccount(readToken(loginBody));
    }

    @Test
    void logoutRevokesOnlyTheCallingToken() throws Exception {
        PROFILES.put("KAKAO:code-5", new SocialProfile("kakao-" + UUID.randomUUID(), "로그아웃러너"));

        String firstDevice = readToken(mockMvc.perform(post("/api/v1/auth/social/kakao")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-5", KAKAO_REDIRECT_URI)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString());

        String secondDevice = readToken(mockMvc.perform(post("/api/v1/auth/social/kakao")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-5", KAKAO_REDIRECT_URI)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString());

        mockMvc.perform(post("/api/v1/auth/logout").header(HttpHeaders.AUTHORIZATION, "Bearer " + firstDevice))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + firstDevice))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + secondDevice))
                .andExpect(status().isOk());

        deleteAccount(secondDevice);
    }

    @Test
    void deletingAccountRemovesCoursesAndAllowsAFreshStart() throws Exception {
        String providerUserId = "kakao-" + UUID.randomUUID();
        PROFILES.put("KAKAO:code-6", new SocialProfile(providerUserId, "삭제러너"));

        String token = readToken(mockMvc.perform(post("/api/v1/auth/social/kakao")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-6", KAKAO_REDIRECT_URI)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString());

        mockMvc.perform(post("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(courseJson("삭제될 코스")))
                .andExpect(status().isCreated());

        mockMvc.perform(delete("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isUnauthorized());

        // The same social account comes back as a brand new user with no data.
        String rejoined = mockMvc.perform(post("/api/v1/auth/social/kakao")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-6", KAKAO_REDIRECT_URI)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String rejoinedToken = readToken(rejoined);

        mockMvc.perform(get("/api/v1/me/courses").header(HttpHeaders.AUTHORIZATION, "Bearer " + rejoinedToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));

        deleteAccount(rejoinedToken);
    }

    @Test
    void unsupportedProviderAndMismatchedRedirectAreRejected() throws Exception {
        mockMvc.perform(post("/api/v1/auth/social/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-x", REDIRECT_URI)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("AUTH_PROVIDER_UNSUPPORTED"));

        mockMvc.perform(post("/api/v1/auth/social/naver")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("code-x", "https://evil.test/callback")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("AUTH_REDIRECT_URI_MISMATCH"));
    }

    @Test
    void providerRejectionIsReportedWithoutLeakingDetails() throws Exception {
        mockMvc.perform(post("/api/v1/auth/social/naver")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginRequest("unknown-code", REDIRECT_URI)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTH_PROVIDER_REJECTED"))
                .andExpect(jsonPath("$.message").value("소셜 로그인에 실패했습니다. 다시 시도해 주세요."));
    }

    @Test
    void authorizeUrlCarriesStateAndRedirectUri() throws Exception {
        mockMvc.perform(get("/api/v1/auth/social/kakao/authorize-url").param("state", "state-123"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.redirectUri").value(KAKAO_REDIRECT_URI))
                // The endpoint host comes from the stubbed client; what matters here
                // is that the OAuth parameters are assembled correctly.
                .andExpect(jsonPath("$.authorizeUrl").value(
                        org.hamcrest.Matchers.allOf(
                                org.hamcrest.Matchers.containsString("response_type=code"),
                                org.hamcrest.Matchers.containsString("state=state-123"),
                                org.hamcrest.Matchers.containsString("scope=profile_nickname"),
                                org.hamcrest.Matchers.containsString("redirect_uri=" + KAKAO_REDIRECT_URI)
                        )
                ));
    }

    @Test
    void callbackForwardsTheCodeToTheAppScheme() throws Exception {
        mockMvc.perform(get("/api/v1/auth/social/naver/callback")
                        .param("code", "abc")
                        .param("state", "xyz"))
                .andExpect(status().isFound())
                .andExpect(result -> {
                    String location = result.getResponse().getHeader("Location");
                    if (location == null
                            || !location.startsWith("coco://oauth/callback")
                            || !location.contains("code=abc")
                            || !location.contains("state=xyz")) {
                        throw new AssertionError("unexpected redirect: " + location);
                    }
                });
    }

    private String issueGuest() throws Exception {
        return mockMvc.perform(post("/api/v1/auth/guest"))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
    }

    private String readToken(String body) {
        return objectMapper.readTree(body).get("token").asText();
    }

    private void deleteAccount(String token) throws Exception {
        mockMvc.perform(delete("/api/v1/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isNoContent());
    }

    private String loginRequest(String code, String redirectUri) {
        return """
                {"code":"%s","redirectUri":"%s"}
                """.formatted(code, redirectUri);
    }

    private String courseJson(String name) {
        return """
                {
                  "name": "%s",
                  "summary": "소셜 로그인 테스트 코스",
                  "difficulty": "EASY",
                  "distanceMeters": 3200,
                  "estimatedDurationSeconds": 1500,
                  "routeSource": "PLANNED_MAPKIT",
                  "routePoints": [
                    {"sequence":0,"latitude":37.526,"longitude":126.93},
                    {"sequence":1,"latitude":37.527,"longitude":126.935}
                  ],
                  "elements": [
                    {"category":"VIEW","latitude":37.527,"longitude":126.935,
                     "distanceFromStartMeters":400,"title":"전망","description":"설명"}
                  ]
                }
                """.formatted(name);
    }
}
