package com.coco.server.auth;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class GuestAuthController {
    private static final String BEARER_PREFIX = "Bearer ";

    private final GuestAuthService guestAuthService;
    private final AuthTokenService authTokenService;

    public GuestAuthController(GuestAuthService guestAuthService, AuthTokenService authTokenService) {
        this.guestAuthService = guestAuthService;
        this.authTokenService = authTokenService;
    }

    @PostMapping("/guest")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse issueGuest() {
        return guestAuthService.issueGuest();
    }

    /// Revokes only the token used for this call so other devices stay signed in.
    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        authTokenService.revoke(authorization.substring(BEARER_PREFIX.length()).trim());
    }
}
