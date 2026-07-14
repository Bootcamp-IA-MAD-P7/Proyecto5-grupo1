package com.sentilife.alerts;

import com.sentilife.monitored.MonitoredPersonRepository;
import com.sentilife.telemetry.TelemetryWindow;
import com.sentilife.telemetry.TelemetryWindowRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.UUID;

/**
 * Decides whether a new alert should be created for a monitored person.
 *
 * Spec §6.3 / ADR-11: 2-of-3 positive windows + 60s cooldown per person.
 * Uses pessimistic lock on the person row to avoid duplicate alerts under concurrency.
 */
@Service
public class AlertDecisionService {

    static final int REQUIRED_POSITIVE = 2;
    static final int WINDOW_LOOKBACK = 3;
    static final Duration COOLDOWN = Duration.ofSeconds(60);

    private final TelemetryWindowRepository windowRepository;
    private final AlertRepository alertRepository;
    private final MonitoredPersonRepository personRepository;
    private final Clock clock;

    public AlertDecisionService(TelemetryWindowRepository windowRepository,
                                AlertRepository alertRepository,
                                MonitoredPersonRepository personRepository,
                                Clock clock) {
        this.windowRepository = windowRepository;
        this.alertRepository = alertRepository;
        this.personRepository = personRepository;
        this.clock = clock;
    }

    /**
     * Evaluates the 2-of-3 rule and cooldown after a window has been persisted.
     * Must run inside the same transaction as alert creation.
     */
    @Transactional
    public boolean shouldCreateAlert(UUID monitoredPersonId) {
        personRepository.findByIdForUpdate(monitoredPersonId)
                .orElseThrow(() -> new IllegalStateException(
                        "Monitored person not found: " + monitoredPersonId));

        List<TelemetryWindow> recent = windowRepository
                .findTop3ByMonitoredPersonIdOrderByWindowStartDesc(monitoredPersonId);

        long positiveCount = recent.stream()
                .filter(w -> Boolean.TRUE.equals(w.getFallDetected()))
                .count();

        if (positiveCount < REQUIRED_POSITIVE) {
            return false;
        }

        return alertRepository.findTopByMonitoredPersonIdOrderByDetectedAtDesc(monitoredPersonId)
                .map(Alert::getDetectedAt)
                .map(lastAt -> lastAt.isBefore(clock.instant().minus(COOLDOWN)))
                .orElse(true);
    }
}
