package com.coco.server.auth.social;

/// Raised when a provider rejects the code exchange or returns an unusable profile.
/// The provider's own message is kept for server logs only and is not returned to clients.
public class SocialProviderException extends RuntimeException {
    public SocialProviderException(String message) {
        super(message);
    }

    public SocialProviderException(String message, Throwable cause) {
        super(message, cause);
    }
}
