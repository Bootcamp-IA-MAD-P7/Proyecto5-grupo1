package com.sentilife.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * RabbitMQ consumer for all caregiver push events (RF-30).
 */
@Component
@ConditionalOnProperty(name = "spring.rabbitmq.listener.simple.auto-startup", havingValue = "true", matchIfMissing = true)
public class CaregiverPushListener {

    private static final Logger log = LoggerFactory.getLogger(CaregiverPushListener.class);

    private final NotificationService notificationService;

    public CaregiverPushListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @RabbitListener(queues = RabbitConfig.PUSH_QUEUE)
    public void onCaregiverNotification(CaregiverNotificationEvent event) {
        log.info("[Push] Processing {} person={}", event.type(), event.monitoredPersonId());

        try {
            switch (event.type()) {
                case CaregiverNotificationEvent.TYPE_FALL_ALERT -> notificationService.sendFallAlert(
                        event.monitoredPersonId(),
                        event.alertId(),
                        event.confidence() != null ? event.confidence() : 0.0);
                case CaregiverNotificationEvent.TYPE_MONITORING_STARTED ->
                        notificationService.sendStatusNotification(
                                CaregiverNotificationEvent.TYPE_MONITORING_STARTED,
                                event.monitoredPersonId());
                case CaregiverNotificationEvent.TYPE_MONITORING_STOPPED ->
                        notificationService.sendStatusNotification(
                                CaregiverNotificationEvent.TYPE_MONITORING_STOPPED,
                                event.monitoredPersonId());
                case CaregiverNotificationEvent.TYPE_CONSENT_REVOKED ->
                        notificationService.sendStatusNotification(
                                CaregiverNotificationEvent.TYPE_CONSENT_REVOKED,
                                event.monitoredPersonId());
                default -> log.warn("[Push] Unknown notification type: {}", event.type());
            }
        } catch (Exception e) {
            log.error("[Push] Failed to send {} for person={}: {}",
                    event.type(), event.monitoredPersonId(), e.getMessage(), e);
        }
    }
}
