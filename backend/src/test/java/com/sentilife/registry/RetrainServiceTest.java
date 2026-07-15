package com.sentilife.registry;

import com.sentilife.admin.AdminDtos;
import com.sentilife.admin.AdminService;
import com.sentilife.config.DomainExceptions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.ObjectMapper;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for retrain pipeline decision logic — T4.4 / RF-33.
 */
@ExtendWith(MockitoExtension.class)
class RetrainServiceTest {

    private static final String INFERENCE_URL = "http://inference:8000";

    @Mock RegistryService registryService;
    @Mock AdminService adminService;
    @Mock RestTemplate restTemplate;

    private RetrainService service;

    @BeforeEach
    void setUp() {
        service = new RetrainService(
                registryService,
                adminService,
                restTemplate,
                new ObjectMapper(),
                INFERENCE_URL,
                5,
                10);
        stubMinimumFeedback(5);
    }

    @Test
    void trigger_rejectsWhenFeedbackBelowMinimum() {
        stubMinimumFeedback(2);

        assertThatThrownBy(() -> service.trigger())
                .isInstanceOf(DomainExceptions.BadRequestException.class);

        var prerequisites = service.getPrerequisites();
        assertThat(prerequisites.eligible()).isFalse();
        assertThat(prerequisites.feedbackRecords()).isEqualTo(2);
        assertThat(prerequisites.minFeedbackRecords()).isEqualTo(5);
    }

    @Test
    void getPrerequisites_reportsEligibleWhenEnoughFeedback() {
        stubMinimumFeedback(6);

        var prerequisites = service.getPrerequisites();
        assertThat(prerequisites.eligible()).isTrue();
        assertThat(prerequisites.feedbackRecords()).isEqualTo(6);
        assertThat(prerequisites.recommendedFeedbackRecords()).isEqualTo(10);
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
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/train"), any(), eq(Map.class)))
                .thenReturn(ResponseEntity.status(503).build());

        service.trigger();
        waitForPhase(RetrainDtos.Phase.FAILED, Duration.ofSeconds(5));

        assertThat(service.getStatus().phase()).isEqualTo(RetrainDtos.Phase.FAILED);
        verify(registryService, never()).register(any());
    }

    @Test
    void trigger_callsPostTrainWithExportBody() throws Exception {
        stubInferenceEndpoints(trainResult(0.88, 0.02, 0.89));
        when(registryService.register(any())).thenReturn(activeModel("candidate-v4"));

        UUID personId = UUID.randomUUID();
        String samplesJson = validSamplesJson();
        stubMinimumFeedback(5);

        service.trigger();
        waitForPhase(RetrainDtos.Phase.COMPLETED, Duration.ofSeconds(5));

        ArgumentCaptor<Map<String, Object>> bodyCaptor = ArgumentCaptor.forClass(Map.class);
        verify(restTemplate).postForEntity(eq(INFERENCE_URL + "/train"), bodyCaptor.capture(), eq(Map.class));
        assertThat(bodyCaptor.getValue()).containsKey("feedback_rows");
        assertThat((List<?>) bodyCaptor.getValue().get("feedback_rows")).hasSize(5);
        verify(restTemplate, never()).getForEntity(contains("/model/info"), eq(Map.class));
    }

    @Test
    void buildTrainRequestBody_serializesExportRows() {
        UUID personId = UUID.randomUUID();
        String samplesJson = validSamplesJson();

        when(adminService.exportLabelledDataset(isNull(), isNull())).thenReturn(List.of(
                new AdminDtos.ExportRow(
                        UUID.randomUUID(),
                        personId,
                        Instant.now(),
                        Instant.now(),
                        50,
                        samplesJson,
                        "TRUE_FALL"
                )
        ));

        Map<String, Object> body = service.buildTrainRequestBody();

        assertThat(body.get("skip_feature_build")).isEqualTo(true);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> rows = (List<Map<String, Object>>) body.get("feedback_rows");
        assertThat(rows).hasSize(1);
        assertThat(rows.get(0).get("label")).isEqualTo("TRUE_FALL");
        assertThat(rows.get(0).get("monitored_person_id")).isEqualTo(personId.toString());
    }

    private void stubMinimumFeedback(int count) {
        UUID personId = UUID.randomUUID();
        String samplesJson = validSamplesJson();
        List<AdminDtos.ExportRow> rows = new java.util.ArrayList<>();
        for (int i = 0; i < count; i++) {
            rows.add(new AdminDtos.ExportRow(
                    UUID.randomUUID(),
                    personId,
                    Instant.now(),
                    Instant.now(),
                    50,
                    samplesJson,
                    i % 2 == 0 ? "TRUE_FALL" : "FALSE_ALARM"
            ));
        }
        when(adminService.exportLabelledDataset(isNull(), isNull())).thenReturn(rows);
    }

    private static String validSamplesJson() {
        StringBuilder signal = new StringBuilder("[");
        for (int i = 0; i < 125; i++) {
            if (i > 0) signal.append(',');
            signal.append("0.1");
        }
        signal.append(']');
        return """
                {"accX":%s,"accY":%s,"accZ":%s,"gyroX":%s,"gyroY":%s,"gyroZ":%s}
                """.formatted(signal, signal, signal, signal, signal, signal);
    }

    private void stubInferenceEndpoints(Map<String, Object> trainResult) {
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/drift/recompute"), isNull(), eq(Map.class)))
                .thenReturn(ResponseEntity.ok(driftResult()));
        when(restTemplate.postForEntity(eq(INFERENCE_URL + "/train"), any(), eq(Map.class)))
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
