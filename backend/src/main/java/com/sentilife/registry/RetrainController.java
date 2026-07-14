package com.sentilife.registry;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * Retrain endpoints — IT_ADMIN only.
 *
 * POST /api/v1/admin/retrain         — trigger a retraining job
 * GET  /api/v1/admin/retrain/status  — poll job progress
 *
 * Flow (ADR-09, patrón proyecto4-grupo4):
 *   1. Admin triggers retrain → job starts async
 *   2. Job phases: DRIFT → TRAINING → EVALUATING → DECIDING
 *   3. Decision: if new recall > old recall AND overfitting < 5%
 *      → model is promoted (ACTIVE), old becomes RETIRED
 *      → inference service is hot-reloaded
 *   4. If decision fails → model stays CANDIDATE, reason logged
 */
@RestController
@RequestMapping("/api/v1/admin/retrain")
@PreAuthorize("hasRole('IT_ADMIN')")
public class RetrainController {

    private final RetrainService service;

    public RetrainController(RetrainService service) {
        this.service = service;
    }

    /**
     * Triggers a new retraining job. Returns immediately with status STARTED.
     * Actual training runs asynchronously.
     */
    @PostMapping
    public ResponseEntity<RetrainDtos.RetrainStatus> triggerRetrain() {
        return ResponseEntity.accepted().body(service.trigger());
    }

    /**
     * Returns the current status of the last retraining job.
     */
    @GetMapping("/status")
    public ResponseEntity<RetrainDtos.RetrainStatus> getStatus() {
        return ResponseEntity.ok(service.getStatus());
    }
}
