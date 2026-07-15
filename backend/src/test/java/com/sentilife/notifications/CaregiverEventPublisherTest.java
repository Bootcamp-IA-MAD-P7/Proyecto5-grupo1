package com.sentilife.notifications;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class CaregiverEventPublisherTest {

    @Mock RabbitTemplate rabbitTemplate;

    @InjectMocks CaregiverEventPublisher publisher;

    @Test
    void publishMonitoringStarted_usesMonitoringStartedRoutingKey() {
        UUID personId = UUID.randomUUID();

        publisher.publishMonitoringStarted(personId);

        ArgumentCaptor<CaregiverNotificationEvent> captor =
                ArgumentCaptor.forClass(CaregiverNotificationEvent.class);
        verify(rabbitTemplate).convertAndSend(
                eq(RabbitConfig.ALERTS_EXCHANGE),
                eq(RabbitConfig.ROUTING_KEY_MONITORING_STARTED),
                captor.capture());
        assertThat(captor.getValue().type()).isEqualTo(CaregiverNotificationEvent.TYPE_MONITORING_STARTED);
        assertThat(captor.getValue().monitoredPersonId()).isEqualTo(personId);
    }

    @Test
    void publishConsentRevoked_usesConsentRevokedRoutingKey() {
        UUID personId = UUID.randomUUID();

        publisher.publishConsentRevoked(personId);

        verify(rabbitTemplate).convertAndSend(
                eq(RabbitConfig.ALERTS_EXCHANGE),
                eq(RabbitConfig.ROUTING_KEY_CONSENT_REVOKED),
                eq(CaregiverNotificationEvent.consentRevoked(personId)));
    }

    @Test
    void routingKeyFor_allStatusTypes() {
        assertThat(CaregiverEventPublisher.routingKeyFor(CaregiverNotificationEvent.TYPE_FALL_ALERT))
                .isEqualTo(RabbitConfig.ROUTING_KEY_ALERT_CREATED);
        assertThat(CaregiverEventPublisher.routingKeyFor(CaregiverNotificationEvent.TYPE_MONITORING_STOPPED))
                .isEqualTo(RabbitConfig.ROUTING_KEY_MONITORING_STOPPED);
    }
}
