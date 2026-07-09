package com.sentilife.devices;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Controlador de vinculación de dispositivos — spec §6.4.
 *
 * POST /api/v1/devices/pair        — público (usa pairingCode)
 * POST /api/v1/devices/push-token  — autenticado (cuidador registra su token FCM)
 */
@RestController
@RequestMapping("/api/v1/devices")
public class DeviceController {

    private final DeviceService service;

    public DeviceController(DeviceService service) {
        this.service = service;
    }

    /**
     * Vincula el dispositivo del monitoreado usando el pairingCode.
     * Público — no requiere JWT.
     */
    @PostMapping("/pair")
    public ResponseEntity<DeviceDtos.PairResponse> pair(
            @Valid @RequestBody DeviceDtos.PairRequest request) {

        return ResponseEntity.ok(service.pair(request));
    }

    /**
     * Registra o actualiza el token FCM del cuidador.
     * Autenticado — requiere JWT (Fase 2).
     * Por ahora acepta userId como path variable hasta tener JWT completo.
     */
    @PostMapping("/push-token")
    public ResponseEntity<Void> registerPushToken(
            @RequestHeader("X-User-Id") UUID userId,
            @Valid @RequestBody DeviceDtos.PushTokenRequest request) {

        service.registerPushToken(userId, request);
        return ResponseEntity.noContent().build();
    }
}
