package com.coco.server.auth;

import com.coco.server.common.ForbiddenOperationException;
import org.springframework.beans.factory.annotation.Value;
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
    private final boolean guestIssuanceEnabled;

    public GuestAuthController(
            GuestAuthService guestAuthService,
            AuthTokenService authTokenService,
            @Value("${coco.auth.guest-issuance-enabled:false}") boolean guestIssuanceEnabled
    ) {
        this.guestAuthService = guestAuthService;
        this.authTokenService = authTokenService;
        this.guestIssuanceEnabled = guestIssuanceEnabled;
    }

    /// Off in production. Every real account now comes from a social provider,
    /// which is what makes an account survive a change of device; an open
    /// endpoint that mints accounts would also let anyone fill the user table.
    /// Tests keep it on so they can authenticate without an OAuth round trip.
    @PostMapping("/guest")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse issueGuest() {
        if (!guestIssuanceEnabled) {
            throw new ForbiddenOperationException(
                    "AUTH_GUEST_DISABLED",
                    "게스트 계정은 더 이상 발급하지 않아요. 소셜 로그인으로 시작해 주세요."
            );
        }
        return guestAuthService.issueGuest();
    }

    /// Revokes only the token used for this call so other devices stay signed in.
    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        authTokenService.revoke(authorization.substring(BEARER_PREFIX.length()).trim());
    }
}
