package com.coco.server.auth.social;

import com.coco.server.auth.AuthResponse;
import com.coco.server.auth.AuthenticatedUser;
import com.coco.server.common.BadRequestException;
import com.coco.server.user.AuthProvider;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.net.URI;
import java.util.Locale;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriComponentsBuilder;

@RestController
@RequestMapping("/api/v1/auth/social")
public class SocialLoginController {
    public record SocialLoginRequest(@NotBlank String code, @NotBlank String redirectUri) {
    }

    private final SocialLoginService socialLoginService;
    private final SocialLoginProperties properties;

    public SocialLoginController(SocialLoginService socialLoginService, SocialLoginProperties properties) {
        this.socialLoginService = socialLoginService;
        this.properties = properties;
    }

    /// Providers only accept https redirect URIs, so they land here first.
    /// This hands the authorization code back to the app's custom scheme
    /// without consuming it or creating a session.
    @GetMapping("/{provider}/callback")
    public ResponseEntity<Void> callback(
            @PathVariable String provider,
            @RequestParam(required = false) String code,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String error
    ) {
        parseProvider(provider);

        UriComponentsBuilder redirect = UriComponentsBuilder
                .fromUriString(properties.appCallbackUrl())
                .queryParam("provider", provider.toLowerCase(Locale.ROOT));
        if (code != null) {
            redirect.queryParam("code", code);
        }
        if (state != null) {
            redirect.queryParam("state", state);
        }
        if (error != null) {
            redirect.queryParam("error", error);
        }

        return ResponseEntity.status(302)
                .location(URI.create(redirect.build().toUriString()))
                .build();
    }

    @PostMapping("/{provider}")
    public AuthResponse login(
            @PathVariable String provider,
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody SocialLoginRequest request
    ) {
        return socialLoginService.login(
                parseProvider(provider),
                request.code(),
                request.redirectUri(),
                currentUser == null ? null : currentUser.id()
        );
    }

    private AuthProvider parseProvider(String provider) {
        try {
            return AuthProvider.valueOf(provider.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException exception) {
            throw new BadRequestException("AUTH_PROVIDER_UNSUPPORTED", "지원하지 않는 로그인 제공자입니다.");
        }
    }
}
