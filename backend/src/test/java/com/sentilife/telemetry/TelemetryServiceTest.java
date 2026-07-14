package com.sentilife.telemetry;

import com.sentilife.alerts.AlertDecisionService;
import com.sentilife.alerts.AlertService;
import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.consent.ConsentRepository;
import com.sentilife.devices.DeviceAuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for TelemetryService — consent filter and fall detection.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class TelemetryServiceTest {

    @Mock TelemetryWindowRepository repository;
    @Mock InferenceClient inferenceClient;
    @Mock ConsentRepository consentRepository;
    @Mock DeviceAuthService deviceAuthService;
    @Mock AlertService alertService;
    @Mock AlertDecisionService alertDecisionService;
    @Mock ABTestingService abTestingService;

    @InjectMocks TelemetryService service;

    @BeforeEach
    void setUp() {
        when(abTestingService.decide())
                .thenReturn(new ABTestingService.ABDecision("baseline-v1", false));
    }

    private TelemetryDtos.WindowRequest buildRequest() {
        return new TelemetryDtos.WindowRequest(
                UUID.randomUUID(), "android-123",
                Instant.now().minusSeconds(3), Instant.now(),
                50,
                Map.of("accX", new double[]{0.1}, "accY", new double[]{9.8},
                       "accZ", new double[]{0.2}, "gyroX", new double[]{1.0},
                       "gyroY", new double[]{0.5}, "gyroZ", new double[]{0.3}),
                null
        );
    }

    private static final String AUTH = "Bearer device-jwt-test";

    // ── device auth gate ──────────────────────────────────────────────────────

    @Test
    void ingest_invalidDeviceAuth_throwsBeforePersist() {
        var request = buildRequest();
        doThrow(DomainExceptions.UnauthorizedException.of("Missing device token"))
                .when(deviceAuthService)
                .validateForIngest(eq(AUTH), eq(request.monitoredPersonId()), eq(request.deviceId()));

        assertThatThrownBy(() -> service.ingest(request, AUTH))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);

        verifyNoInteractions(consentRepository, repository, inferenceClient);
    }

    // ── consent filter ────────────────────────────────────────────────────────

    @Test
    void ingest_noActiveConsent_throwsForbidden() {
        when(consentRepository.existsByMonitoredPersonIdAndStatus(
                any(), eq(DomainConstants.CONSENT_ACTIVE))).thenReturn(false);

        assertThatThrownBy(() -> service.ingest(buildRequest(), AUTH))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);

        verifyNoInteractions(repository, inferenceClient);
    }

    // ── alert aggregation gate ────────────────────────────────────────────────

    @Test
    void ingest_whenDecisionAllows_createsAlert() {
        var request = buildRequest();
        when(consentRepository.existsByMonitoredPersonIdAndStatus(
                any(), eq(DomainConstants.CONSENT_ACTIVE))).thenReturn(true);

        TelemetryWindow saved = new TelemetryWindow();
        when(repository.save(any())).thenReturn(saved);

        var prediction = new TelemetryDtos.PredictionResult(
                true, 0.92, "xgb-1.0", 120);
        when(inferenceClient.predict(any(), any(), anyInt(), any(), any()))
                .thenReturn(prediction);
        when(alertDecisionService.shouldCreateAlert(request.monitoredPersonId()))
                .thenReturn(true);

        service.ingest(request, AUTH);

        verify(alertService).createAlert(any(), eq(0.92), eq("xgb-1.0"), any());
    }

    @Test
    void ingest_whenDecisionBlocks_doesNotCreateAlert() {
        var request = buildRequest();
        when(consentRepository.existsByMonitoredPersonIdAndStatus(
                any(), eq(DomainConstants.CONSENT_ACTIVE))).thenReturn(true);

        TelemetryWindow saved = new TelemetryWindow();
        when(repository.save(any())).thenReturn(saved);

        var prediction = new TelemetryDtos.PredictionResult(
                true, 0.92, "xgb-1.0", 120);
        when(inferenceClient.predict(any(), any(), anyInt(), any(), any()))
                .thenReturn(prediction);
        when(alertDecisionService.shouldCreateAlert(request.monitoredPersonId()))
                .thenReturn(false);

        service.ingest(request, AUTH);

        verifyNoInteractions(alertService);
    }

    @Test
    void ingest_noFall_doesNotCreateAlert() {
        var request = buildRequest();
        when(consentRepository.existsByMonitoredPersonIdAndStatus(
                any(), eq(DomainConstants.CONSENT_ACTIVE))).thenReturn(true);

        TelemetryWindow saved = new TelemetryWindow();
        when(repository.save(any())).thenReturn(saved);

        var prediction = new TelemetryDtos.PredictionResult(
                false, 0.03, "xgb-1.0", 80);
        when(inferenceClient.predict(any(), any(), anyInt(), any(), any()))
                .thenReturn(prediction);
        when(alertDecisionService.shouldCreateAlert(request.monitoredPersonId()))
                .thenReturn(false);

        service.ingest(request, AUTH);

        verifyNoInteractions(alertService);
    }
}
