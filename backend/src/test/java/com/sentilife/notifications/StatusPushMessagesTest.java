package com.sentilife.notifications;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StatusPushMessagesTest {

    @Test
    void monitoringStarted_spanish() {
        StatusPushMessages.Content content = StatusPushMessages.forType(
                CaregiverNotificationEvent.TYPE_MONITORING_STARTED, "es", "Ana");

        assertThat(content.title()).isEqualTo("Monitorización iniciada");
        assertThat(content.body()).contains("Ana");
    }

    @Test
    void consentRevoked_english() {
        StatusPushMessages.Content content = StatusPushMessages.forType(
                CaregiverNotificationEvent.TYPE_CONSENT_REVOKED, "en", "John");

        assertThat(content.title()).isEqualTo("Consent withdrawn");
        assertThat(content.body()).contains("John");
    }

    @Test
    void monitoringStopped_spanish() {
        StatusPushMessages.Content content = StatusPushMessages.forType(
                CaregiverNotificationEvent.TYPE_MONITORING_STOPPED, "es", "María");

        assertThat(content.title()).isEqualTo("Monitorización detenida");
        assertThat(content.body()).contains("María");
    }
}
