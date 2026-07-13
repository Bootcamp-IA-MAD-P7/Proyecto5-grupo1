package com.sentilife.ota;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * OTA Android — rutas legacy /app/* usadas por Flutter y CI.
 */
@RestController
@RequestMapping("/app")
public class OtaController {

    private final OtaService service;

    public OtaController(OtaService service) {
        this.service = service;
    }

    @GetMapping("/latest-version")
    public OtaDtos.LatestVersionResponse latestVersion() {
        return service.latestVersion();
    }

    @PostMapping("/register-version")
    public ResponseEntity<OtaDtos.LatestVersionResponse> register(
            @Valid @RequestBody OtaDtos.RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.register(request));
    }
}
