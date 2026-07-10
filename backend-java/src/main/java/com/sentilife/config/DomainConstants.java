package com.sentilife.config;

/**
 * Constantes compartidas por todo el dominio.
 * Evita hardcodear strings en múltiples servicios.
 */
public class DomainConstants {

    private DomainConstants() {}

    // Locale por defecto
    public static final String DEFAULT_LOCALE = "es";

    // Roles
    public static final String ROLE_MONITORED  = "MONITORED";
    public static final String ROLE_CAREGIVER  = "CAREGIVER";
    public static final String ROLE_IT_ADMIN   = "IT_ADMIN";

    // Estados de consentimiento
    public static final String CONSENT_ACTIVE  = "ACTIVE";
    public static final String CONSENT_REVOKED = "REVOKED";
    public static final String CONSENT_PENDING = "PENDING";

    // Estados de alerta
    public static final String ALERT_PENDING   = "PENDING";
    public static final String ALERT_CONFIRMED = "CONFIRMED";
    public static final String ALERT_DISMISSED = "DISMISSED";

    // Plataformas
    public static final String PLATFORM_ANDROID = "ANDROID";
    public static final String PLATFORM_IOS     = "IOS";

    // Tipos de JWT
    public static final String TOKEN_ACCESS  = "ACCESS";
    public static final String TOKEN_REFRESH = "REFRESH";

    // HTTP
    public static final String BEARER_PREFIX = "Bearer ";

    // Estados de monitorización
    public static final String MONITORING_ACTIVE   = "ACTIVE";
    public static final String MONITORING_INACTIVE = "INACTIVE";
}
