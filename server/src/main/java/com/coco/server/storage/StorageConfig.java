package com.coco.server.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class StorageConfig {
    /// Without credentials the app still starts and every photo endpoint answers
    /// with a clear "not configured" error instead of failing at boot. Tests
    /// supply their own bean, so this one steps aside for them.
    @Bean
    @ConditionalOnMissingBean(ObjectStorage.class)
    public ObjectStorage objectStorage(StorageProperties properties) {
        return properties.isConfigured()
                ? new S3CompatibleObjectStorage(properties)
                : new UnconfiguredObjectStorage();
    }
}
