package com.sentilife.admin;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Admin DTOs — exact contracts from spec §6.6.
 */
public class AdminDtos {

    // ── GET /admin/history ────────────────────────────────────────────────────

    public record HistoryEntry(
        UUID alertId,
        UUID monitoredPersonId,
        String monitoredPersonName,
        Instant detectedAt,
        BigDecimal confidence,
        String modelVersion,
        String alertStatus,
        String feedbackLabel,   // TRUE_FALL | FALSE_ALARM | null (no feedback yet)
        String comment
    ) {}

    // ── GET /admin/monitored-persons ──────────────────────────────────────────

    /** Compact option for IT admin history person filter. */
    public record MonitoredPersonOption(
        UUID id,
        String fullName
    ) {}

    // ── GET /admin/users ──────────────────────────────────────────────────────

    public record UserSummary(
        UUID id,
        String email,
        String fullName,
        String role,
        Boolean active,
        Instant createdAt
    ) {}

    // ── PATCH /admin/users/{id} ───────────────────────────────────────────────

    public record UserStatusRequest(
        Boolean active
    ) {}

    // ── GET /admin/export (CSV rows) ──────────────────────────────────────────

    public record ExportRow(
        UUID windowId,
        UUID monitoredPersonId,
        Instant windowStart,
        Instant windowEnd,
        Integer sampleRateHz,
        String samplesJson,
        String label          // TRUE_FALL | FALSE_ALARM
    ) {}

    // ── POST /admin/retrain ───────────────────────────────────────────────────

    public record RetrainStatus(
        String status,   // idle | running | completed | failed
        String phase,    // drift | training | reload
        String message,
        Instant startedAt,
        Instant finishedAt,
        String decision, // promoted | candidate | discarded | skipped
        RetrainDetails details
    ) {}

    public record RetrainDetails(
        Double currentRecall,
        Double newRecall,
        Double overfittingGap,
        Boolean driftDetected,
        Boolean modelReloaded
    ) {}
}
