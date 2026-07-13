package com.sentilife.notifications;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import java.io.FileInputStream;
import java.io.IOException;

/**
 * Firebase Admin SDK initialization.
 *
 * Reads the service account JSON from the path configured in
 * sentilife.firebase.service-account-path. If the file is not
 * present (e.g., in local dev without Firebase), the app starts
 * normally but push notifications are disabled.
 */
@Configuration
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @Value("${sentilife.firebase.service-account-path:}")
    private String serviceAccountPath;

    private boolean initialized = false;

    @PostConstruct
    public void init() {
        if (serviceAccountPath == null || serviceAccountPath.isBlank()) {
            log.warn("[FCM] No Firebase service account configured — push notifications disabled");
            return;
        }

        try {
            if (FirebaseApp.getApps().isEmpty()) {
                var credentials = GoogleCredentials.fromStream(
                        new FileInputStream(serviceAccountPath));
                var options = FirebaseOptions.builder()
                        .setCredentials(credentials)
                        .build();
                FirebaseApp.initializeApp(options);
                initialized = true;
                log.info("[FCM] Firebase Admin SDK initialized successfully");
            } else {
                initialized = true;
            }
        } catch (IOException e) {
            log.error("[FCM] Failed to initialize Firebase: {} — push notifications disabled",
                    e.getMessage());
        }
    }

    public boolean isInitialized() {
        return initialized;
    }
}
