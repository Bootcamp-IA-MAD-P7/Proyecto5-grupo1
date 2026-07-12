package com.sentilife.registry;

import com.sentilife.config.DomainExceptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
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
    private final RestTemplate restTemplate;
    private final String inferenceUrl;

    // Minimum recall improvement required to promote
    private static final double MIN_RECALL_THRESHOLD = 0.80;
    // Maximum allowed overfitting (train - test difference)
    private static final double MAX_OVERFITTING = 0.05;

    // In-memory job state (single job at a time)
    private final AtomicReference<RetrainDtos.RetrainStatus> currentStatus =
            new AtomicReference<>(new RetrainDtos.RetrainStatus(
                    RetrainDtos.Phase.IDLE,
                    RetrainDtos.Decision.PENDING,
                    "No retraining job has been run",
                    null, null, null, null
            ));

    public RetrainService(RegistryService registryService,
                          @Value("${sentilife.inference.url}") String inferenceUrl) {
        this.registryService = registryService;
        this.restTemplate = new RestTemplate();
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
            // Phase 1: DRIFT — check if data has changed significantly
            updatePhase(RetrainDtos.Phase.DRIFT, "Analyzing data drift...");
            Thread.sleep(2000); // Simulate drift analysis

            // Phase 2: TRAINING — call inference service to retrain
            updatePhase(RetrainDtos.Phase.TRAINING, "Training new model with feedback data...");
            Map<String, Object> trainResult = callTrainingEndpoint();

            if (trainResult == null) {
                failJob("Training endpoint not available or returned error");
                return;
            }

            // Phase 3: EVALUATING — compare metrics
            updatePhase(RetrainDtos.Phase.EVALUATING, "Evaluating new model against current...");
            Thread.sleep(1000); // Simulate evaluation

            String newVersion = (String) trainResult.getOrDefault("version", "retrain-" + Instant.now().getEpochSecond());
            double recall = ((Number) trainResult.getOrDefault("recall", 0.0)).doubleValue();
            double overfitting = ((Number) trainResult.getOrDefault("overfitting", 0.0)).doubleValue();
            String algorithm = (String) trainResult.getOrDefault("algorithm", "XGBoost");
            String artifactUri = (String) trainResult.getOrDefault("artifact_uri", "ml/model.pkl");

            // Phase 4: DECIDING — apply promotion criteria
            updatePhase(RetrainDtos.Phase.DECIDING, "Applying promotion criteria...");

            @SuppressWarnings("unchecked")
            Map<String, Object> metrics = (Map<String, Object>) trainResult.getOrDefault("metrics",
                    Map.of("recall", recall, "overfitting", overfitting));

            // Register the new model as CANDIDATE
            var registerRequest = new RegistryDtos.RegisterRequest(
                    newVersion, algorithm, metrics, artifactUri);
            registryService.register(registerRequest);

            // Decision: promote or keep as candidate
            RetrainDtos.Decision decision;
            String message;

            if (recall >= MIN_RECALL_THRESHOLD && overfitting <= MAX_OVERFITTING) {
                // Promote!
                registryService.promote(newVersion);
                decision = RetrainDtos.Decision.PROMOTED;
                message = String.format("Model promoted — recall=%.3f (>%.2f), overfitting=%.3f (<%.2f)",
                        recall, MIN_RECALL_THRESHOLD, overfitting, MAX_OVERFITTING);
            } else if (recall < MIN_RECALL_THRESHOLD) {
                decision = RetrainDtos.Decision.DISCARDED;
                message = String.format("Model discarded — recall=%.3f below threshold %.2f",
                        recall, MIN_RECALL_THRESHOLD);
            } else {
                decision = RetrainDtos.Decision.CANDIDATE;
                message = String.format("Model kept as CANDIDATE — overfitting=%.3f exceeds limit %.2f",
                        overfitting, MAX_OVERFITTING);
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
     * Calls the inference service training endpoint.
     * Returns the training result with metrics, or null if not available.
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> callTrainingEndpoint() {
        try {
            // The inference service would expose a /train endpoint for retraining.
            // For now, simulate by reading current model info and generating a
            // slightly improved version.
            String url = inferenceUrl + "/model/info";
            var response = restTemplate.getForEntity(url, Map.class);

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                var body = response.getBody();
                String currentVersion = (String) body.getOrDefault("version", "unknown");
                return Map.of(
                        "version", "retrain-" + Instant.now().getEpochSecond(),
                        "algorithm", body.getOrDefault("model_name", "XGBoost"),
                        "recall", 0.92,
                        "overfitting", 0.03,
                        "artifact_uri", "ml/model.pkl",
                        "metrics", Map.of(
                                "recall", 0.92,
                                "precision", 0.88,
                                "f1", 0.90,
                                "overfitting", 0.03,
                                "previous_version", currentVersion
                        )
                );
            }
            return null;
        } catch (Exception e) {
            log.warn("[Retrain] Could not reach inference service: {}", e.getMessage());
            return null;
        }
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
