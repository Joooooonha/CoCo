package com.coco.server.common;

/// Raised when a declared or stored payload exceeds an application limit, as
/// opposed to the servlet-level guard on the request body itself.
public class PayloadTooLargeException extends RuntimeException {
    private final String code;

    public PayloadTooLargeException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
