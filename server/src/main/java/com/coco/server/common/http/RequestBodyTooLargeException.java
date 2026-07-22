package com.coco.server.common.http;

import java.io.IOException;

public class RequestBodyTooLargeException extends IOException {
    public RequestBodyTooLargeException(long maxBytes) {
        super("Request body exceeds " + maxBytes + " bytes");
    }
}
