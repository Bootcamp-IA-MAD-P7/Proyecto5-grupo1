package com.sentilife.telemetry;

import com.sentilife.registry.ModelVersion;
import com.sentilife.registry.ModelVersionRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.concurrent.ThreadLocalRandom;

/**
 * A/B Testing service — routes ~20% of prediction traffic to a CANDIDATE model.
 *
 * How it works:
 * 1. For each prediction request, decides if it should use ACTIVE or CANDIDATE
 * 2. Returns the artifact URI of the model to use
 * 3. Records metrics per model version (Prometheus counters)
 *
 * The inference service supports hot-reload, so we reload the appropriate
 * model before predicting. In a production system you'd have two inference
 * instances; here we simulate A/B by tracking which model served each request.
 *
 * Traffic split: 80% ACTIVE / 20% CANDIDATE (configurable).
 */
@Service
public class ABTestingService {

    private static final Logger log = LoggerFactory.getLogger(ABTestingService.class);
    private static final double CANDIDATE_TRAFFIC_RATIO = 0.20;

    private final ModelVersionRepository modelVersionRepository;
    private final Counter activeCounter;
    private final Counter candidateCounter;

    public ABTestingService(ModelVersionRepository modelVersionRepository,
                            MeterRegistry meterRegistry) {
        this.modelVersionRepository = modelVersionRepository;
        this.activeCounter = Counter.builder("ab_testing_predictions_total")
                .tag("model_status", "ACTIVE")
                .description("Predictions served by the ACTIVE model")
                .register(meterRegistry);
        this.candidateCounter = Counter.builder("ab_testing_predictions_total")
                .tag("model_status", "CANDIDATE")
                .description("Predictions served by the CANDIDATE model")
                .register(meterRegistry);
    }

    /**
     * Decides which model to use for this prediction.
     * Returns the model version string to tag the prediction with.
     *
     * @return ABDecision with the model version and whether it's the candidate
     */
    public ABDecision decide() {
        Optional<ModelVersion> candidate = modelVersionRepository.findByStatus("CANDIDATE");

        if (candidate.isEmpty()) {
            // No candidate available — always use active
            activeCounter.increment();
            return new ABDecision(getActiveVersion(), false);
        }

        // Roll the dice: 20% chance of using candidate
        boolean useCandidate = ThreadLocalRandom.current().nextDouble() < CANDIDATE_TRAFFIC_RATIO;

        if (useCandidate) {
            candidateCounter.increment();
            log.debug("[A/B] Routing to CANDIDATE: {}", candidate.get().getVersion());
            return new ABDecision(candidate.get().getVersion(), true);
        } else {
            activeCounter.increment();
            return new ABDecision(getActiveVersion(), false);
        }
    }

    /**
     * Records the outcome of a prediction for A/B comparison.
     * Called after the prediction is made, to track per-version metrics.
     */
    public void recordOutcome(String modelVersion, boolean fallDetected, double confidence) {
        // Metrics are already tracked by the Counter above.
        // Additional per-version metrics (accuracy, recall) would be computed
        // from feedback_labels once the caregiver confirms/dismisses.
        log.debug("[A/B] Recorded prediction: version={} fall={} confidence={}",
                modelVersion, fallDetected, confidence);
    }

    private String getActiveVersion() {
        return modelVersionRepository.findByStatus("ACTIVE")
                .map(ModelVersion::getVersion)
                .orElse("baseline-v1");
    }

    /**
     * Result of the A/B routing decision.
     */
    public record ABDecision(
            String modelVersion,
            boolean isCandidate
    ) {}
}
