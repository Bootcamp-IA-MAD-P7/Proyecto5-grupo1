package com.sentilife.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * RabbitMQ consumer for alert.created events.
 *
 * Listens on the push queue and sends FCM notifications
 * to the caregiver's registered devices.
 *
 * This runs asynchronously — the telemetry response has already
 * been returned to the caller. Push delivery is best-effort;
 * the caregiver can always poll GET /alerts as fallback.
 */
@Component
public class AlertPushListener {

    private static final Logger log = LoggerFactory.getLogger(AlertPushListener.class);

    private final NotificationService notificationService;

    public AlertPushListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @RabbitListener(queues = RabbitConfig.PUSH_QUEUE)
    public void onAlertCreated(AlertCreatedEvent event) {
        log.info("[Push] Processing alert.created: alertId={} person={} confidence={}",
                event.alertId(), event.monitoredPersonId(), event.confidence());

        try {
            notificationService.sendFallAlert(
                    event.monitoredPersonId(),
                    event.alertId(),
                    event.confidence()
            );
        } catch (Exception e) {
            log.error("[Push] Failed to send notification for alert={}: {}",
                    event.alertId(), e.getMessage(), e);
            // Don't rethrow — message is ACKed to avoid infinite retries.
            // The alert is still available via polling.
        }
    }
}
