package com.sentilife.devices;

import com.sentilife.users.User;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Device pairing controller — spec §6.4.
 *
 * POST /api/v1/devices/pair        — public (uses pairingCode)
 * POST /api/v1/devices/push-token  — authenticated (caregiver registers FCM token)
 * DELETE /api/v1/devices/push-token/{deviceId} — authenticated (logout, idempotent)
 */
@RestController
@RequestMapping("/api/v1/devices")
public class DeviceController {

    private final DeviceService service;

    public DeviceController(DeviceService service) {
        this.service = service;
    }

    /**
     * Pairs the monitored person's device using the pairingCode.
     * Public — no JWT required.
     */
    @PostMapping("/pair")
    public ResponseEntity<DeviceDtos.PairResponse> pair(
            @Valid @RequestBody DeviceDtos.PairRequest request) {
        return ResponseEntity.ok(service.pair(request));
    }

    /**
     * Registers or updates the caregiver's FCM token.
     * Requires authenticated CAREGIVER JWT (T2.22).
     */
    @PostMapping("/push-token")
    public ResponseEntity<Void> registerPushToken(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody DeviceDtos.PushTokenRequest request) {
        service.registerPushToken(user.getId(), request);
        return ResponseEntity.noContent().build();
    }

    /**
     * Unregisters the caregiver's FCM token for this device (T2c.10 / RF-37).
     */
    @DeleteMapping("/push-token/{deviceId}")
    public ResponseEntity<Void> unregisterPushToken(
            @AuthenticationPrincipal User user,
            @PathVariable String deviceId) {
        service.unregisterPushToken(user.getId(), deviceId);
        return ResponseEntity.noContent().build();
    }
}
