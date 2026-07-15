package com.sentilife.notifications;

/**
 * Localized FCM copy for low-priority caregiver status pushes (RF-30 / T5.1).
 */
public final class StatusPushMessages {

    private StatusPushMessages() {}

    public record Content(String title, String body) {}

    public static Content forType(String type, String locale, String personName) {
        boolean en = FallAlertPushMessages.isEnglish(locale);
        return switch (type) {
            case CaregiverNotificationEvent.TYPE_MONITORING_STARTED -> en
                    ? new Content("Monitoring started", personName + " started fall monitoring.")
                    : new Content("Monitorización iniciada", personName + " ha iniciado la monitorización.");
            case CaregiverNotificationEvent.TYPE_MONITORING_STOPPED -> en
                    ? new Content("Monitoring stopped", personName + " stopped fall monitoring.")
                    : new Content("Monitorización detenida", personName + " ha detenido la monitorización.");
            case CaregiverNotificationEvent.TYPE_CONSENT_REVOKED -> en
                    ? new Content("Consent withdrawn", personName + " revoked data collection consent.")
                    : new Content("Consentimiento revocado", personName + " revocó el consentimiento de recogida.");
            default -> throw new IllegalArgumentException("Not a status push type: " + type);
        };
    }
}
