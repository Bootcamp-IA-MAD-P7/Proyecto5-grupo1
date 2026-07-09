package com.sentilife.telemetry;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.Map;
import java.util.UUID;

/**
 * Cliente HTTP hacia el servicio de inferencia FastAPI.
 * Solo el backend Java llama a este servicio — nunca el exterior.
 *
 * Contrato de spec §6.8:
 *   POST /predict → { fallDetected, confidence, modelVersion, latencyMs }
 */
@Component
public class InferenceClient {

    private static final Logger log = LoggerFactory.getLogger(InferenceClient.class);

    private final RestClient restClient;

    public InferenceClient(@Value("${sentilife.inference.url}") String inferenceUrl) {
        this.restClient = RestClient.builder()
                .baseUrl(inferenceUrl)
                .build();
    }

    /**
     * Llama a FastAPI /predict con los datos de la ventana.
     * Si falla, devuelve una predicción de fallback (no bloquea la ingesta).
     */
    public TelemetryDtos.PredictionResult predict(
            UUID windowId,
            UUID monitoredPersonId,
            int sampleRateHz,
            Map<String, Object> samples,
            Map<String, Object> subjectFeatures) {

        try {
            var request = Map.of(
                "windowId",          windowId.toString(),
                "monitoredId",       monitoredPersonId.toString(),
                "sampleRateHz",      sampleRateHz,
                "samples",           samples,
                "subjectFeatures",   subjectFeatures != null ? subjectFeatures : Map.of()
            );

            long start = System.currentTimeMillis();

            @SuppressWarnings("unchecked")
            Map<String, Object> response = restClient.post()
                    .uri("/predict")
                    .body(request)
                    .retrieve()
                    .body(Map.class);

            long latency = System.currentTimeMillis() - start;

            if (response == null) {
                return fallbackPrediction("null-response");
            }

            return new TelemetryDtos.PredictionResult(
                Boolean.TRUE.equals(response.get("fallDetected")),
                toDouble(response.get("confidence")),
                String.valueOf(response.getOrDefault("modelVersion", "unknown")),
                (int) latency
            );

        } catch (RestClientException e) {
            log.error("Error calling inference service: {}", e.getMessage());
            return fallbackPrediction("inference-unavailable");
        }
    }

    private TelemetryDtos.PredictionResult fallbackPrediction(String reason) {
        log.warn("Using fallback prediction (reason: {})", reason);
        return new TelemetryDtos.PredictionResult(false, 0.0, reason, 0);
    }

    private double toDouble(Object value) {
        if (value instanceof Number n) return n.doubleValue();
        return 0.0;
    }
}
