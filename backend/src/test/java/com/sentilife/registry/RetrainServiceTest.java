package com.sentilife.registry;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for retrain pipeline decision logic — T4.4 / RF-33.
 */
@ExtendWith(MockitoExtension.class)
class RetrainServiceTest {

    private static final String INFERENCE_URL = "http://inference:8000";

    @Mock RegistryService registryService;
    @Mock RestTemplate restTemplate;

    private RetrainService service;

    @BeforeEach
    void setUp() {
        service = new RetrainService(registryService, restTemplate, INFERENCE_URL);
    }

    @Test
    void pipeline_promotesWhenRecallImprovesAndOverfittingLow() throws Exception {
        stubInferenceEndpoints(trainResult(0.93, 0.02, 0.89));
        when(registryService.register(any())).thenReturn(activeModel("candidate-v1"));

        service.trigger();
        waitForPhase(RetrainDtos.Phase.COMPLETED, Duration.ofSeconds(5));

        var status = service.getStatus();
        assertThat(status.phase()).isEqualTo(RetrainDtos.Phase.COMPLETED);
        assertThat(status.decision()).isEqualTo(RetrainDtos.Decision.PROMOTED);
        assertThat(status.modelVersion()).isEqualTo("xgboost-retrain-test");
        verify(registryService).promote("xgboost-retrain-test");

        ArgumentCaptor<RegistryDtos.RegisterRequest> captor =
                ArgumentCaptor.forClass(RegistryDtos.RegisterRequest.class);
        verify(registryService).register(captor.capture());
        assertThat(captor.getValue().artifactUri()).isEqualTo("ml/models/retrain-test.pkl");
    }

    @Test
    void pipeline_discardsWhenRecallDoesNotImprove() throws Exception {
        stubInferenceEndpoints(trainResult(0.88, 0.02, 0.89));
        when(registryService.register(any())).thenReturn(activeModel("candidate-v2"));

        service.trigger();
        waitForPhase(RetrainDtos.Phase.COMPLETED, Duration.ofSeconds(5));

        var status = service.getStatus();
        assertThat(status.decision()).isEqualTo(RetrainDtos.Decision.DISCARDED);
        verify(registryService, never()).promote(anyString());
    }

    @Test
    void pipeline_keepsCandidateWhenOverfittingTooHigh() throws Exception {
        stubInferenceEndpoints(trainResult(0.93, 0.08, 0.89));
        when(registryService.register(any())).thenReturn(activeModel("candidate-v3"));

        service.trigger();
        waitForPhase(RetrainDtos.Phase.COMPLETED, Duration.ofSeconds(5));

        var status = service.getStatus();
        assertThat(status.decision()).isEqualTo(RetrainDtos.Decision.CANDIDATE);
        verify(registryService, never()).promote(anyString());
    }

    @Test
    void pipeline_failsWhenTrainEndpointUnavailable() throws Exception {
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/drift/recompute"), isNull(), eq(Map.class)))
                .thenReturn(ResponseEntity.ok(driftResult()));
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/train"), isNull(), eq(Map.class)))
                .thenReturn(ResponseEntity.status(503).build());

        service.trigger();
        waitForPhase(RetrainDtos.Phase.FAILED, Duration.ofSeconds(5));

        assertThat(service.getStatus().phase()).isEqualTo(RetrainDtos.Phase.FAILED);
        verify(registryService, never()).register(any());
    }

    @Test
    void trigger_callsPostTrainNotModelInfo() throws Exception {
        stubInferenceEndpoints(trainResult(0.88, 0.02, 0.89));
        when(registryService.register(any())).thenReturn(activeModel("candidate-v4"));

        service.trigger();
        waitForPhase(RetrainDtos.Phase.COMPLETED, Duration.ofSeconds(5));

        verify(restTemplate).postForEntity(eq(INFERENCE_URL + "/train"), isNull(), eq(Map.class));
        verify(restTemplate, never()).getForEntity(contains("/model/info"), eq(Map.class));
    }

    private void stubInferenceEndpoints(Map<String, Object> trainResult) {
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/drift/recompute"), isNull(), eq(Map.class)))
                .thenReturn(ResponseEntity.ok(driftResult()));
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/train"), isNull(), eq(Map.class)))
                .thenReturn(ResponseEntity.ok(trainResult));
    }

    private static Map<String, Object> driftResult() {
        return Map.of(
                "psi", 0.12,
                "drift_detected", false,
                "samples", 42,
                "status", "ok"
        );
    }

    private static Map<String, Object> trainResult(double recall, double overfitting, double currentRecall) {
        return Map.of(
                "version", "xgboost-retrain-test",
                "algorithm", "XGBoost",
                "recall", recall,
                "precision", 0.75,
                "f1", 0.82,
                "overfitting", overfitting,
                "artifact_uri", "ml/models/retrain-test.pkl",
                "metrics", Map.of(
                        "recall", recall,
                        "precision", 0.75,
                        "f1", 0.82,
                        "overfitting", overfitting,
                        "current_recall", currentRecall
                )
        );
    }

    private static RegistryDtos.ModelVersionResponse activeModel(String version) {
        return new RegistryDtos.ModelVersionResponse(
                UUID.randomUUID(),
                version,
                "XGBoost",
                Map.of("recall", 0.89),
                "ml/models/model.pkl",
                "CANDIDATE",
                java.time.Instant.now()
        );
    }

    private void waitForPhase(RetrainDtos.Phase expected, Duration timeout) throws InterruptedException {
        long deadline = System.nanoTime() + timeout.toNanos();
        while (System.nanoTime() < deadline) {
            if (service.getStatus().phase() == expected) {
                return;
            }
            Thread.sleep(50);
        }
        assertThat(service.getStatus().phase())
                .as("Expected phase %s but got %s", expected, service.getStatus().phase())
                .isEqualTo(expected);
    }
}
