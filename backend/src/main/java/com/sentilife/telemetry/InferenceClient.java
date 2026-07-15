package com.sentilife.telemetry;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.config.DomainExceptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * HTTP client for the FastAPI inference service.
 * Only the Java backend calls this service — never exposed externally.
 *
 * Contract spec §6.8:
 *   POST /predict → { fallDetected, confidence, modelVersion, latencyMs }
 */
@Component
public class InferenceClient {

    private static final Logger log = LoggerFactory.getLogger(InferenceClient.class);

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String predictUrl;
    private final boolean failFast;

    @Autowired
    public InferenceClient(@Value("${sentilife.inference.url}") String inferenceUrl,
                           @Value("${sentilife.inference.fail-fast:false}") boolean failFast,
                           ObjectMapper objectMapper) {
        this(inferenceUrl, failFast, objectMapper, new RestTemplate());
    }

    /** Package-private for unit tests with a mock {@link RestTemplate}. */
    InferenceClient(String inferenceUrl,
                    boolean failFast,
                    ObjectMapper objectMapper,
                    RestTemplate restTemplate) {
        this.objectMapper = objectMapper;
        this.restTemplate = restTemplate;
        this.predictUrl = inferenceUrl + "/predict";
        this.failFast = failFast;
    }

    /**
     * Calls FastAPI /predict with the window data.
     * On failure, returns a fallback prediction in dev (fail-fast=false) so ingestion
     * is not blocked; in prod (fail-fast=true) propagates HTTP 503.
     */
    public TelemetryDtos.PredictionResult predict(
            UUID windowId,
            UUID monitoredPersonId,
            int sampleRateHz,
            Map<String, Object> samples,
            Map<String, Object> subjectFeatures) {

        try {
            var request = new HashMap<String, Object>();
            request.put("windowId", windowId.toString());
            request.put("monitoredId", monitoredPersonId.toString());
            request.put("sampleRateHz", sampleRateHz);
            request.put("samples", samples);
            request.put("subjectFeatures", subjectFeatures != null ? subjectFeatures : Map.of());

            String jsonBody = objectMapper.writeValueAsString(request);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            long start = System.currentTimeMillis();

            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.postForObject(
                    predictUrl,
                    new HttpEntity<>(jsonBody, headers),
                    Map.class);

            long latency = System.currentTimeMillis() - start;

            if (response == null) {
                return handleInferenceFailure("null-response");
            }

            return new TelemetryDtos.PredictionResult(
                Boolean.TRUE.equals(response.get("fallDetected")),
                toDouble(response.get("confidence")),
                String.valueOf(response.getOrDefault("modelVersion", "unknown")),
                (int) latency
            );

        } catch (JsonProcessingException e) {
            log.error("Error serializing inference request: {}", e.getMessage());
            return handleInferenceFailure("serialization-error");
        } catch (RestClientException e) {
            log.error("Error calling inference service: {}", e.getMessage());
            return handleInferenceFailure("inference-unavailable");
        }
    }

    private TelemetryDtos.PredictionResult handleInferenceFailure(String reason) {
        if (failFast) {
            throw DomainExceptions.ServiceUnavailableException.of(
                    "Inference service unavailable: " + reason);
        }
        log.warn("Using fallback prediction (reason: {})", reason);
        return new TelemetryDtos.PredictionResult(false, 0.0, reason, 0);
    }

    private double toDouble(Object value) {
        if (value instanceof Number n) return n.doubleValue();
        return 0.0;
    }
}
