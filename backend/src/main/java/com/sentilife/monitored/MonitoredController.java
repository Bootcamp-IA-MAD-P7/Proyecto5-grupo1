package com.sentilife.monitored;

import com.sentilife.config.DomainConstants;
import com.sentilife.users.User;
import jakarta.validation.constraints.Email;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Monitored persons CRUD controller — spec §6.2.
 * Requires CAREGIVER role (Spring Security validates the JWT).
 *
 * POST   /api/v1/monitored-persons           — create person
 * GET    /api/v1/monitored-persons           — list my persons (paginated)
 * GET    /api/v1/monitored-persons/{id}      — detail
 * PUT    /api/v1/monitored-persons/{id}      — update
 * DELETE /api/v1/monitored-persons/{id}      — delete + GDPR suppression
 * POST   /api/v1/monitored-persons/{id}/consent   — accept consent
 * DELETE /api/v1/monitored-persons/{id}/consent   — revoke consent
 */
@RestController
@RequestMapping("/api/v1/monitored-persons")
public class MonitoredController {

    private final MonitoredService service;

    public MonitoredController(MonitoredService service) {
        this.service = service;
    }

    @PostMapping
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<MonitoredDtos.MonitoredResponse> create(
            @AuthenticationPrincipal User caregiver,
            @Valid @RequestBody MonitoredDtos.MonitoredRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.create(caregiver.getId(), request));
    }

    @GetMapping
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<Page<MonitoredDtos.MonitoredResponse>> list(
            @AuthenticationPrincipal User caregiver,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(service.listByCaegiver(caregiver.getId(), pageable));
    }

    @GetMapping("/me")
    @PreAuthorize("hasRole('MONITORED')")
    public ResponseEntity<MonitoredDtos.MonitoredResponse> getMyProfile(
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(service.getByMonitoredUserId(user.getId()));
    }

    @GetMapping("/linkable-account")
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<MonitoredDtos.LinkableAccountResponse> lookupLinkableAccount(
            @RequestParam @Email String email) {
        return ResponseEntity.ok(service.lookupLinkableAccount(email));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<MonitoredDtos.MonitoredResponse> getById(
            @AuthenticationPrincipal User caregiver,
            @PathVariable UUID id) {
        return ResponseEntity.ok(service.getById(caregiver.getId(), id));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<MonitoredDtos.MonitoredResponse> update(
            @AuthenticationPrincipal User caregiver,
            @PathVariable UUID id,
            @Valid @RequestBody MonitoredDtos.MonitoredRequest request) {
        return ResponseEntity.ok(service.update(caregiver.getId(), id, request));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal User caregiver,
            @PathVariable UUID id) {
        service.delete(caregiver.getId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/consent")
    @PreAuthorize("hasAnyRole('CAREGIVER', 'MONITORED')")
    public ResponseEntity<MonitoredDtos.ConsentResponse> acceptConsent(
            @AuthenticationPrincipal User user,
            @PathVariable UUID id,
            @Valid @RequestBody MonitoredDtos.ConsentRequest request) {
        MonitoredDtos.ConsentResponse response;
        if (DomainConstants.ROLE_MONITORED.equals(user.getRole())) {
            response = service.acceptConsentByMonitored(id, request);
        } else {
            response = service.acceptConsent(user.getId(), id, request);
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @DeleteMapping("/{id}/consent")
    @PreAuthorize("hasAnyRole('CAREGIVER', 'MONITORED')")
    public ResponseEntity<MonitoredDtos.ConsentResponse> revokeConsent(
            @AuthenticationPrincipal User user,
            @PathVariable UUID id) {
        MonitoredDtos.ConsentResponse response;
        if (DomainConstants.ROLE_MONITORED.equals(user.getRole())) {
            response = service.revokeConsentByMonitored(id);
        } else {
            response = service.revokeConsent(user.getId(), id);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{id}/monitoring-events")
    @PreAuthorize("hasRole('MONITORED')")
    public ResponseEntity<Void> publishMonitoringEvent(
            @AuthenticationPrincipal User user,
            @PathVariable UUID id,
            @Valid @RequestBody MonitoredDtos.MonitoringEventRequest request) {
        service.publishMonitoringEvent(user.getId(), id, request.event());
        return ResponseEntity.noContent().build();
    }
}
