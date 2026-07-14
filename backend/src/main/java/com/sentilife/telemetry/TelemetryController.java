package com.sentilife.telemetry;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Telemetry HTTP controller — spec §6.3.
 *
 * POST /api/v1/telemetry/windows              — ingest window + prediction
 * GET  /api/v1/telemetry/status/{personId}    — monitored person status
 */
@RestController
@RequestMapping("/api/v1/telemetry")
public class TelemetryController {

    private final TelemetryService service;

    public TelemetryController(TelemetryService service) {
        this.service = service;
    }

    /**
     * Receives a sensor window, persists it and returns the prediction.
     * 200 OK with { windowId, prediction }
     * 403 if no active consent (implemented in Phase 2)
     */
    @PostMapping("/windows")
    public ResponseEntity<TelemetryDtos.WindowResponse> ingestWindow(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody TelemetryDtos.WindowRequest request) {
        return ResponseEntity.ok(service.ingest(request, authorization));
    }

    /**
     * Monitoring status of a person — used by the CAREGIVER profile.
     * Returns the last window and prediction.
     */
    @GetMapping("/status/{monitoredPersonId}")
    public ResponseEntity<TelemetryDtos.MonitoringStatus> getStatus(
            @PathVariable UUID monitoredPersonId) {
        return ResponseEntity.ok(service.getStatus(monitoredPersonId));
    }
}
