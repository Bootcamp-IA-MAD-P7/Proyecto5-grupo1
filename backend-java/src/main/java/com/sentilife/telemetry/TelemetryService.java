package com.sentilife.telemetry;

import com.sentilife.config.DomainConstants;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

/**
 * Business logic for telemetry ingestion.
 *
 * Flow (spec §6.3, ADR-02 synchronous critical path):
 *   1. Persist the window in PostgreSQL (ADR-03 fallback)
 *   2. Call FastAPI synchronously to get the prediction
 *   3. Update the window with the result
 *   4. Return the prediction to the controller
 *
 * Note: consent validation will be added in Phase 2
 * once the consent module is implemented.
 */
@Service
public class TelemetryService {

    private static final Logger log = LoggerFactory.getLogger(TelemetryService.class);

    private final TelemetryWindowRepository repository;
    private final InferenceClient inferenceClient;

    public TelemetryService(TelemetryWindowRepository repository,
                            InferenceClient inferenceClient) {
        this.repository      = repository;
        this.inferenceClient = inferenceClient;
    }

    @Transactional
    public TelemetryDtos.WindowResponse ingest(TelemetryDtos.WindowRequest request) {
        log.debug("Ingesting window for person={} device={}",
                request.monitoredPersonId(), request.deviceId());

        // 1. Persist the window
        TelemetryWindow window = new TelemetryWindow();
        window.setMonitoredPersonId(request.monitoredPersonId());
        window.setDeviceId(request.deviceId());
        window.setWindowStart(request.windowStart());
        window.setWindowEnd(request.windowEnd());
        window.setSampleRateHz(request.sampleRateHz());
        window.setSamplesJson(request.samples());
        window.setContextJson(request.context());
        window = repository.save(window);

        // 2. Call FastAPI synchronously — critical path ADR-02
        TelemetryDtos.PredictionResult prediction = inferenceClient.predict(
                window.getId(),
                request.monitoredPersonId(),
                request.sampleRateHz(),
                request.samples(),
                buildSubjectFeatures(request.context())
        );

        // 3. Update the window with the prediction result
        window.setFallDetected(prediction.fallDetected());
        window.setConfidence(BigDecimal.valueOf(prediction.confidence()));
        window.setModelVersion(prediction.modelVersion());
        window.setLatencyMs(prediction.latencyMs());
        repository.save(window);

        if (prediction.fallDetected()) {
            log.warn("FALL DETECTED — person={} confidence={} window={}",
                    request.monitoredPersonId(), prediction.confidence(), window.getId());
            // TODO SL-34: publish alert when the alerts module is implemented
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
                    return new TelemetryDtos.MonitoringStatus(
                            DomainConstants.MONITORING_ACTIVE, w.getWindowStart(), last);
                })
                .orElse(new TelemetryDtos.MonitoringStatus(
                        DomainConstants.MONITORING_INACTIVE, null, null));
    }

    private Map<String, Object> buildSubjectFeatures(Map<String, Object> context) {
        // Phase 2: enrich with monitored person's data (age, sex, weight, height)
        return context != null ? context : Map.of();
    }
}
