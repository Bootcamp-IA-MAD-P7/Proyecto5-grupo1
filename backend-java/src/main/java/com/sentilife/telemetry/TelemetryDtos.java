package com.sentilife.telemetry;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * DTOs de telemetría — contratos exactos de spec §6.3.
 */
public class TelemetryDtos {

    // ── Request: POST /telemetry/windows ─────────────────────────────────────

    public record WindowRequest(
        @NotNull UUID monitoredPersonId,
        @NotBlank String deviceId,
        @NotNull Instant windowStart,
        @NotNull Instant windowEnd,
        @NotNull @Positive Integer sampleRateHz,
        @NotNull Map<String, Object> samples,   // accX, accY, accZ, gyroX, gyroY, gyroZ
        Map<String, Object> context             // heartRate, roomTemp, roomLight (opcional)
    ) {}

    // ── Response: predicción en línea ─────────────────────────────────────────

    public record PredictionResult(
        boolean fallDetected,
        double confidence,
        String modelVersion,
        int latencyMs
    ) {}

    public record WindowResponse(
        UUID windowId,
        PredictionResult prediction
    ) {}

    // ── Response: GET /telemetry/status/{monitoredPersonId} ──────────────────

    public record MonitoringStatus(
        String monitoringStatus,   // ACTIVE | INACTIVE
        Instant lastWindowAt,
        PredictionResult lastPrediction
    ) {}
}
