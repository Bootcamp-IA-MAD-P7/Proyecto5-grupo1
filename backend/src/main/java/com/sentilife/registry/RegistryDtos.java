package com.sentilife.registry;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * DTOs for the model registry endpoints.
 */
public class RegistryDtos {

    // ── Register a new model version ──────────────────────────────────────────

    public record RegisterRequest(
            @NotBlank String version,
            @NotBlank String algorithm,
            @NotNull Map<String, Object> metrics,
            @NotBlank String artifactUri
    ) {}

    // ── Response ──────────────────────────────────────────────────────────────

    public record ModelVersionResponse(
            UUID id,
            String version,
            String algorithm,
            Map<String, Object> metrics,
            String artifactUri,
            String status,
            Instant createdAt
    ) {}

    // ── Promote / retire ──────────────────────────────────────────────────────

    public record PromoteResponse(
            String promoted,
            String previousActive,
            boolean reloadTriggered
    ) {}
}
