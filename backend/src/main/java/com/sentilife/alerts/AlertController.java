package com.sentilife.alerts;

import com.sentilife.users.User;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Alerts controller — spec §6.5.
 * Requires CAREGIVER role.
 *
 * GET   /api/v1/alerts       — list alerts (optional ?status=PENDING)
 * PATCH /api/v1/alerts/{id}  — submit feedback (CONFIRMED | DISMISSED)
 */
@RestController
@RequestMapping("/api/v1/alerts")
@PreAuthorize("hasRole('CAREGIVER')")
public class AlertController {

    private final AlertService service;

    public AlertController(AlertService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<Page<AlertDtos.AlertResponse>> list(
            @AuthenticationPrincipal User caregiver,
            @RequestParam(required = false) String status,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(service.listAlerts(caregiver.getId(), status, pageable));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<AlertDtos.FeedbackResponse> submitFeedback(
            @AuthenticationPrincipal User caregiver,
            @PathVariable UUID id,
            @Valid @RequestBody AlertDtos.FeedbackRequest request) {
        return ResponseEntity.ok(service.submitFeedback(caregiver.getId(), id, request));
    }
}
