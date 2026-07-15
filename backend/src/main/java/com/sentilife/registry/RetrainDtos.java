package com.sentilife.registry;

import java.time.Instant;
import java.util.Map;

/**
 * DTOs for the retraining pipeline.
 */
public class RetrainDtos {

    /**
     * Phases of the retraining pipeline.
     */
    public enum Phase {
        IDLE,           // No job running
        DRIFT,          // Checking data drift
        TRAINING,       // Training new model
        EVALUATING,     // Evaluating against current model
        DECIDING,       // Comparing metrics, deciding promotion
        COMPLETED,      // Job finished (check decision)
        FAILED          // Job failed (check message)
    }

    /**
     * Decision outcome after evaluation.
     */
    public enum Decision {
        PROMOTED,       // New model is better → now ACTIVE
        CANDIDATE,      // New model exists but not promoted (didn't beat threshold)
        DISCARDED,      // New model is worse → discarded
        SKIPPED,        // Job not started — insufficient feedback (RF-45)
        PENDING         // Decision not yet made
    }

    /**
     * Status of the current/last retraining job.
     */
    public record RetrainStatus(
            Phase phase,
            Decision decision,
            String message,
            String modelVersion,
            Map<String, Object> metrics,
            Instant startedAt,
            Instant completedAt
    ) {}

    /**
     * Feedback eligibility before starting a retrain job (RF-45).
     */
    public record RetrainPrerequisites(
            int feedbackRecords,
            int minFeedbackRecords,
            int recommendedFeedbackRecords,
            boolean eligible,
            String message
    ) {}
}
