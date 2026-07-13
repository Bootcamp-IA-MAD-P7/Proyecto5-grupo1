package com.sentilife.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Publishes alert.created events to RabbitMQ.
 *
 * Called by AlertService after persisting a new alert.
 * The message is consumed asynchronously by AlertPushListener
 * to send FCM push notifications.
 *
 * If RabbitTemplate is not available (e.g., in tests without
 * a broker), publishing is silently skipped.
 */
@Component
public class AlertEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(AlertEventPublisher.class);

    private final RabbitTemplate rabbitTemplate;

    public AlertEventPublisher(@Autowired(required = false) RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    /**
     * Publishes an alert.created event to the alerts exchange.
     * Non-blocking — failures are logged but do not affect the caller.
     */
    public void publishAlertCreated(UUID alertId, UUID monitoredPersonId,
                                    double confidence, String modelVersion) {
        if (rabbitTemplate == null) {
            log.debug("[Events] RabbitMQ not available — skipping alert.created for alertId={}", alertId);
            return;
        }

        var event = new AlertCreatedEvent(alertId, monitoredPersonId, confidence, modelVersion);
        try {
            rabbitTemplate.convertAndSend(
                    RabbitConfig.ALERTS_EXCHANGE,
                    RabbitConfig.ROUTING_KEY,
                    event
            );
            log.debug("[Events] Published alert.created: alertId={}", alertId);
        } catch (Exception e) {
            log.error("[Events] Failed to publish alert.created for alertId={}: {}",
                    alertId, e.getMessage());
            // Non-critical — alert is persisted, polling works as fallback
        }
    }
}
