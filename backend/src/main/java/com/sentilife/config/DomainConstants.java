package com.sentilife.config;

/**
 * Domain-wide constants.
 * Centralizes all magic strings to avoid hardcoding across services.
 */
public class DomainConstants {

    private DomainConstants() {}

    // Default locale
    public static final String DEFAULT_LOCALE = "es";

    // Roles
    public static final String ROLE_MONITORED = "MONITORED";
    public static final String ROLE_CAREGIVER = "CAREGIVER";
    public static final String ROLE_IT_ADMIN  = "IT_ADMIN";

    // Consent statuses
    public static final String CONSENT_ACTIVE  = "ACTIVE";
    public static final String CONSENT_REVOKED = "REVOKED";
    public static final String CONSENT_PENDING = "PENDING";

    // Alert statuses
    public static final String ALERT_PENDING   = "PENDING";
    public static final String ALERT_CONFIRMED = "CONFIRMED";
    public static final String ALERT_DISMISSED = "DISMISSED";

    // Platforms
    public static final String PLATFORM_ANDROID = "ANDROID";
    public static final String PLATFORM_IOS     = "IOS";

    // JWT token types
    public static final String TOKEN_ACCESS  = "ACCESS";
    public static final String TOKEN_REFRESH = "REFRESH";

    // HTTP
    public static final String BEARER_PREFIX = "Bearer ";

    // Monitoring statuses
    public static final String MONITORING_ACTIVE   = "ACTIVE";
    public static final String MONITORING_INACTIVE = "INACTIVE";

    // Model registry statuses
    public static final String MODEL_ACTIVE    = "ACTIVE";
    public static final String MODEL_CANDIDATE = "CANDIDATE";
    public static final String MODEL_RETIRED   = "RETIRED";
}
