package com.sentilife.notifications;

import java.util.UUID;

/**
 * Unified RabbitMQ payload for caregiver push notifications (RF-30).
 * Consumed by {@link CaregiverPushListener}.
 */
public record CaregiverNotificationEvent(
        String type,
        UUID monitoredPersonId,
        UUID alertId,
        Double confidence,
        String modelVersion
) {
    public static final String TYPE_FALL_ALERT = "FALL_ALERT";
    public static final String TYPE_MONITORING_STARTED = "MONITORING_STARTED";
    public static final String TYPE_MONITORING_STOPPED = "MONITORING_STOPPED";
    public static final String TYPE_CONSENT_REVOKED = "CONSENT_REVOKED";

    public static CaregiverNotificationEvent fallAlert(UUID alertId, UUID monitoredPersonId,
                                                       double confidence, String modelVersion) {
        return new CaregiverNotificationEvent(
                TYPE_FALL_ALERT, monitoredPersonId, alertId, confidence, modelVersion);
    }

    public static CaregiverNotificationEvent monitoringStarted(UUID monitoredPersonId) {
        return new CaregiverNotificationEvent(
                TYPE_MONITORING_STARTED, monitoredPersonId, null, null, null);
    }

    public static CaregiverNotificationEvent monitoringStopped(UUID monitoredPersonId) {
        return new CaregiverNotificationEvent(
                TYPE_MONITORING_STOPPED, monitoredPersonId, null, null, null);
    }

    public static CaregiverNotificationEvent consentRevoked(UUID monitoredPersonId) {
        return new CaregiverNotificationEvent(
                TYPE_CONSENT_REVOKED, monitoredPersonId, null, null, null);
    }
}
