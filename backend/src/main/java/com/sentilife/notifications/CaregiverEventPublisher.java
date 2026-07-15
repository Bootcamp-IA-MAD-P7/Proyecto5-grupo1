package com.sentilife.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Publishes caregiver notification events to RabbitMQ (RF-30).
 */
@Component
public class CaregiverEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(CaregiverEventPublisher.class);

    private final RabbitTemplate rabbitTemplate;

    public CaregiverEventPublisher(@Autowired(required = false) RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void publishFallAlert(UUID alertId, UUID monitoredPersonId,
                                 double confidence, String modelVersion) {
        publish(CaregiverNotificationEvent.fallAlert(
                alertId, monitoredPersonId, confidence, modelVersion));
    }

    public void publishMonitoringStarted(UUID monitoredPersonId) {
        publish(CaregiverNotificationEvent.monitoringStarted(monitoredPersonId));
    }

    public void publishMonitoringStopped(UUID monitoredPersonId) {
        publish(CaregiverNotificationEvent.monitoringStopped(monitoredPersonId));
    }

    public void publishConsentRevoked(UUID monitoredPersonId) {
        publish(CaregiverNotificationEvent.consentRevoked(monitoredPersonId));
    }

    void publish(CaregiverNotificationEvent event) {
        if (rabbitTemplate == null) {
            log.debug("[Events] RabbitMQ not available — skipping {} for person={}",
                    event.type(), event.monitoredPersonId());
            return;
        }

        String routingKey = routingKeyFor(event.type());
        try {
            rabbitTemplate.convertAndSend(RabbitConfig.ALERTS_EXCHANGE, routingKey, event);
            log.debug("[Events] Published {} person={}", event.type(), event.monitoredPersonId());
        } catch (Exception e) {
            log.error("[Events] Failed to publish {} for person={}: {}",
                    event.type(), event.monitoredPersonId(), e.getMessage());
        }
    }

    static String routingKeyFor(String type) {
        return switch (type) {
            case CaregiverNotificationEvent.TYPE_FALL_ALERT -> RabbitConfig.ROUTING_KEY_ALERT_CREATED;
            case CaregiverNotificationEvent.TYPE_MONITORING_STARTED ->
                    RabbitConfig.ROUTING_KEY_MONITORING_STARTED;
            case CaregiverNotificationEvent.TYPE_MONITORING_STOPPED ->
                    RabbitConfig.ROUTING_KEY_MONITORING_STOPPED;
            case CaregiverNotificationEvent.TYPE_CONSENT_REVOKED ->
                    RabbitConfig.ROUTING_KEY_CONSENT_REVOKED;
            default -> throw new IllegalArgumentException("Unknown notification type: " + type);
        };
    }
}
