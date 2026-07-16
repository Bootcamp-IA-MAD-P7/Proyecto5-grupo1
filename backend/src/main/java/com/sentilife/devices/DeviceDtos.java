package com.sentilife.devices;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * Device pairing and push token DTOs — spec §6.4.
 */
public class DeviceDtos {

    // ── POST /devices/pair ────────────────────────────────────────────────────

    public record PairRequest(
        @NotBlank String pairingCode,
        @NotBlank String deviceId,
        @NotBlank String platform    // ANDROID | IOS
    ) {}

    public record PairResponse(
        UUID monitoredPersonId,
        String deviceToken           // JWT device token for POST /telemetry/windows
    ) {}

    // ── GET /devices/my-pairing ───────────────────────────────────────────────

    public record MyPairingResponse(
        UUID monitoredPersonId,
        String deviceId,
        String deviceToken           // Fresh JWT device token
    ) {}

    // ── POST /devices/push-token ──────────────────────────────────────────────

    public record PushTokenRequest(
        @NotBlank String fcmToken,
        @NotBlank String deviceId,
        @NotBlank String platform,
        String locale
    ) {}
}
