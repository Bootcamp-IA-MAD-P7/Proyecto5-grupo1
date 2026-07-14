package com.sentilife.notifications;

/**
 * Localized FCM notification copy for fall alerts (RF-31 / T3.7).
 *
 * Uses the caregiver device locale stored in {@code push_tokens.locale}.
 */
public final class FallAlertPushMessages {

    private FallAlertPushMessages() {}

    public record Content(String title, String body) {}

    public static Content forLocale(String locale, String personName, int confidencePercent) {
        if (isEnglish(locale)) {
            return new Content(
                    "Fall Alert",
                    String.format("%s may have fallen (confidence: %d%%)", personName, confidencePercent)
            );
        }
        return new Content(
                "Alerta de caída",
                String.format("%s podría haber caído (confianza: %d%%)", personName, confidencePercent)
        );
    }

    static boolean isEnglish(String locale) {
        return locale != null && locale.toLowerCase().startsWith("en");
    }
}
