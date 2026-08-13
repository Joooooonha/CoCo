package com.coco.server.auth.social;

import com.coco.server.user.AuthProvider;

/// Exchanges an authorization code for a provider profile.
/// Implementations keep the client secret server-side and never expose
/// the provider access token beyond this call.
public interface SocialProviderClient {
    AuthProvider provider();

    String authorizationEndpoint();

    SocialProfile fetchProfile(String authorizationCode, String redirectUri);
}
