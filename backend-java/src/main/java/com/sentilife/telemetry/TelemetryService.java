package com.sentilife.telemetry;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

/**
 * Lógica de negocio para la ingesta de telemetría.
 *
 * Flujo (spec §6.3, ADR-02 camino crítico síncrono):
 *   1. Valida que la ventana tiene datos mínimos
 *   2. Persiste la ventana en PostgreSQL (fallback ADR-03)
 *   3. Llama síncronamente a FastAPI para obtener la predicción
 *   4. Actualiza la ventana con el resultado
 *   5. Devuelve la predicción al controlador
 *
 * Nota: la validación de consentimiento se añade en Fase 2
 * cuando esté implementado el módulo de consent.
 */
@Service
public class TelemetryService {

    private static final Logger log = LoggerFactory.getLogger(TelemetryService.class);

    private final TelemetryWindowRepository repository;
    private final InferenceClient inferenceClient;

    public TelemetryService(TelemetryWindowRepository repository,
                            InferenceClient inferenceClient) {
        this.repository = repository;
        this.inferenceClient = inferenceClient;
    }

    @Transactional
    public TelemetryDtos.WindowResponse ingest(TelemetryDtos.WindowRequest request) {
        log.debug("Ingesting window for person={} device={}",
                request.monitoredPersonId(), request.deviceId());

        // 1. Persistir la ventana
        TelemetryWindow window = new TelemetryWindow();
        window.setMonitoredPersonId(request.monitoredPersonId());
        window.setDeviceId(request.deviceId());
        window.setWindowStart(request.windowStart());
        window.setWindowEnd(request.windowEnd());
        window.setSampleRateHz(request.sampleRateHz());
        window.setSamplesJson(request.samples());
        window.setContextJson(request.context());
        window = repository.save(window);

        // 2. Llamar a FastAPI (síncrono — camino crítico ADR-02)
        TelemetryDtos.PredictionResult prediction = inferenceClient.predict(
                window.getId(),
                request.monitoredPersonId(),
                request.sampleRateHz(),
                request.samples(),
                buildSubjectFeatures(request.context())
        );

        // 3. Actualizar la ventana con el resultado
        window.setFallDetected(prediction.fallDetected());
        window.setConfidence(BigDecimal.valueOf(prediction.confidence()));
        window.setModelVersion(prediction.modelVersion());
        window.setLatencyMs(prediction.latencyMs());
        repository.save(window);

        if (prediction.fallDetected()) {
            log.warn("FALL DETECTED — person={} confidence={} window={}",
                    request.monitoredPersonId(), prediction.confidence(), window.getId());
            // TODO SL-34: publicar alerta cuando esté implementado el módulo de alertas
        }

        return new TelemetryDtos.WindowResponse(window.getId(), prediction);
    }

    public TelemetryDtos.MonitoringStatus getStatus(UUID monitoredPersonId) {
        return repository.findLastByMonitoredPersonId(monitoredPersonId)
                .map(w -> {
                    TelemetryDtos.PredictionResult last = w.getFallDetected() != null
                            ? new TelemetryDtos.PredictionResult(
                                w.getFallDetected(),
                                w.getConfidence() != null ? w.getConfidence().doubleValue() : 0.0,
                                w.getModelVersion() != null ? w.getModelVersion() : "unknown",
                                w.getLatencyMs() != null ? w.getLatencyMs() : 0)
                            : null;
                    return new TelemetryDtos.MonitoringStatus("ACTIVE", w.getWindowStart(), last);
                })
                .orElse(new TelemetryDtos.MonitoringStatus("INACTIVE", null, null));
    }

    private Map<String, Object> buildSubjectFeatures(Map<String, Object> context) {
        // En Fase 2, aquí se enriquece con los datos de la persona monitorizada
        // (edad, sexo, peso, altura) consultando monitored_persons
        return context != null ? context : Map.of();
    }
}
