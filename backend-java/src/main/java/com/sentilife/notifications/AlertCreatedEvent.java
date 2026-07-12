package com.sentilife.notifications;

import java.util.UUID;

/**
 * Event published when a fall alert is created.
 * Consumed by the push notification listener via RabbitMQ.
 */
public record AlertCreatedEvent(
        UUID alertId,
        UUID monitoredPersonId,
        double confidence,
        String modelVersion
) {}
