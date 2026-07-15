package com.sentilife.registry;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.admin.AdminDtos;
import com.sentilife.admin.AdminService;
import com.sentilife.config.DomainExceptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Retraining pipeline orchestrator.
 *
 * Calls the inference service's retrain endpoint (or a separate training
 * script) and evaluates the result against configurable thresholds.
 *
 * Decision criteria (constitución §7, ADR-09):
 * - New model recall for falls > current model recall
 * - Overfitting (train - test metric) < 5%
 * - Split by subject maintained (LOSO/GroupKFold)
 *
 * This is an in-memory state machine. In production, you'd persist
 * job state to the database for resilience across restarts.
 */
@Service
public class RetrainService {

    private static final Logger log = LoggerFactory.getLogger(RetrainService.class);

    private final RegistryService registryService;
    private final AdminService adminService;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String inferenceUrl;

    // Maximum allowed overfitting (train - test recall difference)
    private static final double MAX_OVERFITTING = 0.05;

    // In-memory job state (single job at a time)
    private final AtomicReference<RetrainDtos.RetrainStatus> currentStatus =
            new AtomicReference<>(new RetrainDtos.RetrainStatus(
                    RetrainDtos.Phase.IDLE,
                    RetrainDtos.Decision.PENDING,
                    "No retraining job has been run",
                    null, null, null, null
            ));

    @Autowired
    public RetrainService(RegistryService registryService,
                          AdminService adminService,
                          @Value("${sentilife.inference.url}") String inferenceUrl) {
        this(registryService, adminService, new RestTemplate(), new ObjectMapper(), inferenceUrl);
    }

    /** Package-private for unit tests (T4.4 / T4d.1). */
    RetrainService(RegistryService registryService,
                   AdminService adminService,
                   RestTemplate restTemplate,
                   ObjectMapper objectMapper,
                   String inferenceUrl) {
        this.registryService = registryService;
        this.adminService = adminService;
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.inferenceUrl = inferenceUrl;
    }

    /**
     * Triggers a new retraining job asynchronously.
     * Returns the initial status immediately.
     */
    public RetrainDtos.RetrainStatus trigger() {
        var current = currentStatus.get();
        if (current.phase() == RetrainDtos.Phase.TRAINING ||
            current.phase() == RetrainDtos.Phase.EVALUATING ||
            current.phase() == RetrainDtos.Phase.DECIDING) {
            throw DomainExceptions.ConflictException.of(
                    "A retraining job is already in progress: " + current.phase());
        }

        var status = new RetrainDtos.RetrainStatus(
                RetrainDtos.Phase.DRIFT,
                RetrainDtos.Decision.PENDING,
                "Retraining job started — checking data drift",
                null, null, Instant.now(), null
        );
        currentStatus.set(status);

        // Run the actual pipeline async (non-blocking)
        CompletableFuture.runAsync(this::runPipeline);

        return status;
    }

    /**
     * Returns the current status of the last retraining job.
     */
    public RetrainDtos.RetrainStatus getStatus() {
        return currentStatus.get();
    }

    /**
     * Runs the full retraining pipeline asynchronously.
     * Phases: DRIFT → TRAINING → EVALUATING → DECIDING → COMPLETED/FAILED
     */
    private void runPipeline() {
        try {
            // Phase 1: DRIFT — PSI vs SisFall training baseline (T4.7 / ML-18)
            updatePhase(RetrainDtos.Phase.DRIFT, "Analyzing data drift...");
            Map<String, Object> driftResult = callDriftEndpoint();
            if (driftResult == null) {
                failJob("Drift endpoint not available");
                return;
            }

            double driftPsi = ((Number) driftResult.getOrDefault("psi", 0.0)).doubleValue();
            boolean driftDetected = Boolean.TRUE.equals(driftResult.get("drift_detected"));
            int driftSamples = ((Number) driftResult.getOrDefault("samples", 0)).intValue();

            var driftMetrics = Map.of(
                    "drift_psi", driftPsi,
                    "drift_detected", driftDetected,
                    "drift_samples", driftSamples,
                    "drift_status", driftResult.getOrDefault("status", "unknown")
            );
            var prev = currentStatus.get();
            currentStatus.set(new RetrainDtos.RetrainStatus(
                    RetrainDtos.Phase.DRIFT,
                    RetrainDtos.Decision.PENDING,
                    String.format("Drift analysis complete — PSI=%.3f detected=%s samples=%d",
                            driftPsi, driftDetected, driftSamples),
                    prev.modelVersion(),
                    driftMetrics,
                    prev.startedAt(),
                    null
            ));
            log.info("[Retrain] Drift PSI={} detected={} samples={}", driftPsi, driftDetected, driftSamples);

            // Phase 2: TRAINING — call inference service to retrain
            updatePhase(RetrainDtos.Phase.TRAINING, "Training new model with feedback data...");
            Map<String, Object> trainResult = callTrainingEndpoint();

            if (trainResult == null) {
                failJob("Training endpoint not available or returned error");
                return;
            }

            // Phase 3: EVALUATING — compare metrics against current ACTIVE model
            updatePhase(RetrainDtos.Phase.EVALUATING, "Evaluating new model against current...");

            String newVersion = (String) trainResult.getOrDefault("version", "retrain-" + Instant.now().getEpochSecond());
            double recall = ((Number) trainResult.getOrDefault("recall", 0.0)).doubleValue();
            double overfitting = ((Number) trainResult.getOrDefault("overfitting", 0.0)).doubleValue();
            String algorithm = (String) trainResult.getOrDefault("algorithm", "XGBoost");
            String artifactUri = (String) trainResult.getOrDefault("artifact_uri", "ml/model.pkl");

            // Phase 4: DECIDING — apply promotion criteria (ADR-09)
            updatePhase(RetrainDtos.Phase.DECIDING, "Applying promotion criteria...");

            @SuppressWarnings("unchecked")
            Map<String, Object> metrics = (Map<String, Object>) trainResult.getOrDefault("metrics",
                    Map.of("recall", recall, "overfitting", overfitting));

            double currentRecall = resolveCurrentRecall(metrics);

            // Register the new model as CANDIDATE
            var registerRequest = new RegistryDtos.RegisterRequest(
                    newVersion, algorithm, metrics, artifactUri);
            registryService.register(registerRequest);

            // Decision: promote only if recall improves AND overfitting within limit
            RetrainDtos.Decision decision;
            String message;

            if (recall > currentRecall && overfitting <= MAX_OVERFITTING) {
                registryService.promote(newVersion);
                decision = RetrainDtos.Decision.PROMOTED;
                message = String.format(
                        "Model promoted — recall=%.3f (was %.3f), overfitting=%.3f (<=%.2f)",
                        recall, currentRecall, overfitting, MAX_OVERFITTING);
            } else if (recall <= currentRecall) {
                decision = RetrainDtos.Decision.DISCARDED;
                message = String.format(
                        "Model discarded — recall=%.3f did not improve over current %.3f",
                        recall, currentRecall);
            } else {
                decision = RetrainDtos.Decision.CANDIDATE;
                message = String.format(
                        "Model kept as CANDIDATE — overfitting=%.3f exceeds limit %.2f (recall %.3f > %.3f)",
                        overfitting, MAX_OVERFITTING, recall, currentRecall);
            }

            currentStatus.set(new RetrainDtos.RetrainStatus(
                    RetrainDtos.Phase.COMPLETED,
                    decision,
                    message,
                    newVersion,
                    metrics,
                    currentStatus.get().startedAt(),
                    Instant.now()
            ));

            log.info("[Retrain] Pipeline completed: decision={} version={} message={}",
                    decision, newVersion, message);

        } catch (Exception e) {
            failJob("Pipeline error: " + e.getMessage());
            log.error("[Retrain] Pipeline failed", e);
        }
    }

    /**
     * Calls the inference service drift endpoint (PSI vs training baseline).
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> callDriftEndpoint() {
        try {
            String url = inferenceUrl + "/drift/recompute";
            var response = restTemplate.postForEntity(url, null, Map.class);
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                return response.getBody();
            }
            return null;
        } catch (Exception e) {
            log.warn("[Retrain] Could not compute drift: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Calls the inference service training endpoint (POST /train).
     * Returns the training result with real metrics, or null if not available.
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> callTrainingEndpoint() {
        try {
            String url = inferenceUrl + "/train";
            Map<String, Object> body = buildTrainRequestBody();
            var response = restTemplate.postForEntity(url, body, Map.class);

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                return response.getBody();
            }
            return null;
        } catch (Exception e) {
            log.warn("[Retrain] Training endpoint failed: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Exports labelled windows from Postgres and serializes them for POST /train (T4d.1).
     */
    Map<String, Object> buildTrainRequestBody() {
        List<AdminDtos.ExportRow> rows = adminService.exportLabelledDataset(null, null);
        List<Map<String, Object>> feedbackRows = new ArrayList<>();

        for (AdminDtos.ExportRow row : rows) {
            Map<String, Object> samples = parseSamplesJson(row.samplesJson());
            if (samples == null) {
                log.warn("[Retrain] Skipping export row {} — invalid samples_json", row.windowId());
                continue;
            }
            feedbackRows.add(Map.of(
                    "monitored_person_id", row.monitoredPersonId().toString(),
                    "samples", samples,
                    "label", row.label()
            ));
        }

        Map<String, Object> body = new HashMap<>();
        body.put("feedback_rows", feedbackRows);
        body.put("skip_feature_build", true);
        log.info("[Retrain] POST /train with {} feedback_rows from DB export", feedbackRows.size());
        return body;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseSamplesJson(String samplesJson) {
        if (samplesJson == null || samplesJson.isBlank()) {
            return null;
        }
        try {
            Map<String, Object> parsed = objectMapper.readValue(
                    samplesJson, new TypeReference<>() {});
            Object nested = parsed.get("samples");
            if (nested instanceof Map<?, ?> nestedMap) {
                parsed = (Map<String, Object>) nestedMap;
            }
            for (String signal : List.of("accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ")) {
                if (!(parsed.get(signal) instanceof List<?> values) || values.size() != 125) {
                    return null;
                }
            }
            return parsed;
        } catch (Exception e) {
            log.warn("[Retrain] Could not parse samples_json: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Resolves recall of the current ACTIVE model for promotion comparison.
     */
    private double resolveCurrentRecall(Map<String, Object> trainMetrics) {
        Object fromTrain = trainMetrics.get("current_recall");
        if (fromTrain instanceof Number n) {
            return n.doubleValue();
        }
        try {
            var active = registryService.getActive();
            Object recall = active.metrics().get("recall");
            if (recall == null) {
                recall = active.metrics().get("recall_fall_test");
            }
            if (recall instanceof Number n) {
                return n.doubleValue();
            }
        } catch (Exception e) {
            log.warn("[Retrain] Could not read active model recall: {}", e.getMessage());
        }
        return 0.0;
    }

    private void updatePhase(RetrainDtos.Phase phase, String message) {
        var prev = currentStatus.get();
        currentStatus.set(new RetrainDtos.RetrainStatus(
                phase, RetrainDtos.Decision.PENDING, message,
                prev.modelVersion(), prev.metrics(), prev.startedAt(), null
        ));
    }

    private void failJob(String message) {
        var prev = currentStatus.get();
        currentStatus.set(new RetrainDtos.RetrainStatus(
                RetrainDtos.Phase.FAILED,
                RetrainDtos.Decision.DISCARDED,
                message,
                prev.modelVersion(), prev.metrics(), prev.startedAt(), Instant.now()
        ));
    }
}
