package com.sentilife.notifications;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class FallAlertPushMessagesTest {

    @Test
    void forLocale_english() {
        FallAlertPushMessages.Content content =
                FallAlertPushMessages.forLocale("en", "Maria Lopez", 87);

        assertThat(content.title()).isEqualTo("Fall Alert");
        assertThat(content.body()).isEqualTo("Maria Lopez may have fallen (confidence: 87%)");
    }

    @Test
    void forLocale_spanish_default() {
        FallAlertPushMessages.Content content =
                FallAlertPushMessages.forLocale("es", "María López", 87);

        assertThat(content.title()).isEqualTo("Alerta de caída");
        assertThat(content.body()).isEqualTo("María López podría haber caído (confianza: 87%)");
    }

    @Test
    void forLocale_nullOrUnknown_fallsBackToSpanish() {
        FallAlertPushMessages.Content content =
                FallAlertPushMessages.forLocale(null, "Ana", 50);

        assertThat(content.title()).isEqualTo("Alerta de caída");
        assertThat(content.body()).contains("Ana");
        assertThat(content.body()).contains("50%");
    }
}
