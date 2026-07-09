package com.sentilife.telemetry;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Controlador HTTP de telemetría — spec §6.3.
 *
 * POST /api/v1/telemetry/windows  — ingesta de ventana + predicción
 * GET  /api/v1/telemetry/status/{monitoredPersonId} — estado del monitoreado
 */
@RestController
@RequestMapping("/api/v1/telemetry")
public class TelemetryController {

    private final TelemetryService service;

    public TelemetryController(TelemetryService service) {
        this.service = service;
    }

    /**
     * Recibe una ventana de sensores, la persiste y devuelve la predicción.
     * 200 OK con { windowId, prediction }
     * 403 si no hay consentimiento activo (implementado en Fase 2)
     */
    @PostMapping("/windows")
    public ResponseEntity<TelemetryDtos.WindowResponse> ingestWindow(
            @Valid @RequestBody TelemetryDtos.WindowRequest request) {

        TelemetryDtos.WindowResponse response = service.ingest(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Estado de monitorización de una persona — para el perfil CAREGIVER.
     * Devuelve la última ventana y predicción.
     */
    @GetMapping("/status/{monitoredPersonId}")
    public ResponseEntity<TelemetryDtos.MonitoringStatus> getStatus(
            @PathVariable UUID monitoredPersonId) {

        return ResponseEntity.ok(service.getStatus(monitoredPersonId));
    }
}
