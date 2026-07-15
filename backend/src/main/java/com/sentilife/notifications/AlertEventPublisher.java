package com.sentilife.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Publishes alert.created events to RabbitMQ.
 * Delegates to {@link CaregiverEventPublisher} (RF-30 unified pipeline).
 */
@Component
public class AlertEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(AlertEventPublisher.class);

    private final CaregiverEventPublisher caregiverEventPublisher;

    public AlertEventPublisher(CaregiverEventPublisher caregiverEventPublisher) {
        this.caregiverEventPublisher = caregiverEventPublisher;
    }

    public void publishAlertCreated(UUID alertId, UUID monitoredPersonId,
                                    double confidence, String modelVersion) {
        log.debug("[Events] Publishing alert.created: alertId={}", alertId);
        caregiverEventPublisher.publishFallAlert(alertId, monitoredPersonId, confidence, modelVersion);
    }
}
