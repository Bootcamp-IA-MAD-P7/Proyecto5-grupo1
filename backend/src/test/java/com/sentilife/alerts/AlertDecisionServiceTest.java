package com.sentilife.alerts;

import com.sentilife.monitored.MonitoredPerson;
import com.sentilife.monitored.MonitoredPersonRepository;
import com.sentilife.telemetry.TelemetryWindow;
import com.sentilife.telemetry.TelemetryWindowRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for alert aggregation (2-of-3) and 60s cooldown — T2c.6.
 */
@ExtendWith(MockitoExtension.class)
class AlertDecisionServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-14T12:00:00Z");

    @Mock TelemetryWindowRepository windowRepository;
    @Mock AlertRepository alertRepository;
    @Mock MonitoredPersonRepository personRepository;

    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
    private AlertDecisionService service;

    private final UUID personId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new AlertDecisionService(
                windowRepository, alertRepository, personRepository, clock);
        when(personRepository.findByIdForUpdate(personId))
                .thenReturn(Optional.of(new MonitoredPerson()));
    }

    private TelemetryWindow window(boolean fallDetected, Instant windowStart) {
        TelemetryWindow w = new TelemetryWindow();
        w.setMonitoredPersonId(personId);
        w.setFallDetected(fallDetected);
        w.setWindowStart(windowStart);
        return w;
    }

    @Test
    void onePositiveOfThree_doesNotAlert() {
        when(windowRepository.findTop3ByMonitoredPersonIdOrderByWindowStartDesc(personId))
                .thenReturn(List.of(
                        window(true, NOW),
                        window(false, NOW.minusSeconds(3)),
                        window(false, NOW.minusSeconds(6))));

        assertThat(service.shouldCreateAlert(personId)).isFalse();
    }

    @Test
    void twoPositiveOfThree_alerts() {
        when(windowRepository.findTop3ByMonitoredPersonIdOrderByWindowStartDesc(personId))
                .thenReturn(List.of(
                        window(true, NOW),
                        window(true, NOW.minusSeconds(3)),
                        window(false, NOW.minusSeconds(6))));
        when(alertRepository.findTopByMonitoredPersonIdOrderByDetectedAtDesc(personId))
                .thenReturn(Optional.empty());

        assertThat(service.shouldCreateAlert(personId)).isTrue();
    }

    @Test
    void twoPositiveWithinCooldown_doesNotAlert() {
        when(windowRepository.findTop3ByMonitoredPersonIdOrderByWindowStartDesc(personId))
                .thenReturn(List.of(
                        window(true, NOW),
                        window(true, NOW.minusSeconds(3)),
                        window(false, NOW.minusSeconds(6))));

        Alert lastAlert = new Alert();
        lastAlert.setDetectedAt(NOW.minusSeconds(30));
        when(alertRepository.findTopByMonitoredPersonIdOrderByDetectedAtDesc(personId))
                .thenReturn(Optional.of(lastAlert));

        assertThat(service.shouldCreateAlert(personId)).isFalse();
    }

    @Test
    void twoPositiveAfterCooldown_alerts() {
        when(windowRepository.findTop3ByMonitoredPersonIdOrderByWindowStartDesc(personId))
                .thenReturn(List.of(
                        window(true, NOW),
                        window(true, NOW.minusSeconds(3)),
                        window(false, NOW.minusSeconds(6))));

        Alert lastAlert = new Alert();
        lastAlert.setDetectedAt(NOW.minusSeconds(61));
        when(alertRepository.findTopByMonitoredPersonIdOrderByDetectedAtDesc(personId))
                .thenReturn(Optional.of(lastAlert));

        assertThat(service.shouldCreateAlert(personId)).isTrue();
    }

    @Test
    void zeroPositive_doesNotAlert() {
        when(windowRepository.findTop3ByMonitoredPersonIdOrderByWindowStartDesc(personId))
                .thenReturn(List.of(
                        window(false, NOW),
                        window(false, NOW.minusSeconds(3)),
                        window(false, NOW.minusSeconds(6))));

        assertThat(service.shouldCreateAlert(personId)).isFalse();
    }

    @Test
    void acquiresPersonRowLockForAtomicDecision() {
        when(windowRepository.findTop3ByMonitoredPersonIdOrderByWindowStartDesc(personId))
                .thenReturn(List.of(
                        window(true, NOW),
                        window(true, NOW.minusSeconds(3))));
        when(alertRepository.findTopByMonitoredPersonIdOrderByDetectedAtDesc(personId))
                .thenReturn(Optional.empty());

        service.shouldCreateAlert(personId);

        verify(personRepository).findByIdForUpdate(personId);
    }
}
