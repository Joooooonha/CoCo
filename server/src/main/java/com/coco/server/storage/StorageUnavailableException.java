package com.coco.server.storage;

public class StorageUnavailableException extends RuntimeException {
    public StorageUnavailableException() {
        super("Object storage credentials are not configured");
    }
}
