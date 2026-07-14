package com.sentilife.registry;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Model registry endpoints — IT_ADMIN only.
 *
 * POST   /api/v1/admin/models          — register a new model version
 * POST   /api/v1/admin/models/{version}/promote — promote CANDIDATE → ACTIVE
 * GET    /api/v1/admin/models          — list all versions
 * GET    /api/v1/admin/models/active    — get the current active model
 */
@RestController
@RequestMapping("/api/v1/admin/models")
@PreAuthorize("hasRole('IT_ADMIN')")
public class RegistryController {

    private final RegistryService service;

    public RegistryController(RegistryService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<RegistryDtos.ModelVersionResponse> register(
            @Valid @RequestBody RegistryDtos.RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.register(request));
    }

    @PostMapping("/{version}/promote")
    public ResponseEntity<RegistryDtos.PromoteResponse> promote(
            @PathVariable String version) {
        return ResponseEntity.ok(service.promote(version));
    }

    @GetMapping
    public ResponseEntity<List<RegistryDtos.ModelVersionResponse>> listAll() {
        return ResponseEntity.ok(service.listAll());
    }

    @GetMapping("/active")
    public ResponseEntity<RegistryDtos.ModelVersionResponse> getActive() {
        return ResponseEntity.ok(service.getActive());
    }
}
