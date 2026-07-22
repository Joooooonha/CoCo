package com.coco.server.security;

import com.coco.server.auth.AuthenticatedUser;
import com.coco.server.auth.GuestAuthService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Optional;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedCredentialsNotFoundException;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class BearerTokenAuthenticationFilter extends OncePerRequestFilter {
    private static final String BEARER_PREFIX = "Bearer ";

    private final GuestAuthService guestAuthService;
    private final ApiAuthenticationEntryPoint authenticationEntryPoint;

    public BearerTokenAuthenticationFilter(
            GuestAuthService guestAuthService,
            ApiAuthenticationEntryPoint authenticationEntryPoint
    ) {
        this.guestAuthService = guestAuthService;
        this.authenticationEntryPoint = authenticationEntryPoint;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String authorization = request.getHeader("Authorization");
        if (authorization == null) {
            filterChain.doFilter(request, response);
            return;
        }

        if (!authorization.startsWith(BEARER_PREFIX)) {
            reject(request, response);
            return;
        }

        String rawToken = authorization.substring(BEARER_PREFIX.length()).trim();
        if (rawToken.isEmpty()) {
            reject(request, response);
            return;
        }

        Optional<AuthenticatedUser> user = guestAuthService.authenticate(rawToken);
        if (user.isEmpty()) {
            reject(request, response);
            return;
        }

        UsernamePasswordAuthenticationToken authentication = UsernamePasswordAuthenticationToken.authenticated(
                user.get(),
                null,
                List.of()
        );
        SecurityContextHolder.getContext().setAuthentication(authentication);
        filterChain.doFilter(request, response);
    }

    private void reject(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
        AuthenticationException exception = new PreAuthenticatedCredentialsNotFoundException("Invalid bearer token");
        authenticationEntryPoint.commence(request, response, exception);
    }
}
