package com.sentilife.alerts;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Alert DTOs — exact contracts from spec §6.5.
 */
public class AlertDtos {

    // ── GET /alerts response ──────────────────────────────────────────────────

    public record AlertResponse(
        UUID id,
        UUID monitoredPersonId,
        String monitoredPersonName,
        Instant detectedAt,
        BigDecimal confidence,
        String modelVersion,
        String status          // PENDING | CONFIRMED | DISMISSED
    ) {}

    // ── PATCH /alerts/{id} ────────────────────────────────────────────────────

    public record FeedbackRequest(
        @NotBlank @Pattern(regexp = "CONFIRMED|DISMISSED") String status,
        String comment
    ) {}

    public record FeedbackResponse(
        UUID alertId,
        String status,
        UUID feedbackLabelId
    ) {}
}
