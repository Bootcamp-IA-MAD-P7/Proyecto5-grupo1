package com.sentilife.devices;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.config.JwtService;
import com.sentilife.monitored.MonitoredPersonRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

/**
 * Business logic for device pairing and push token management.
 *
 * pair: finds the person by pairingCode, registers the device and
 *       returns a device token for use in POST /telemetry/windows.
 *
 * registerPushToken: registers or updates the caregiver's FCM token.
 *                    Idempotent: same userId + deviceId updates the token.
 */
@Service
public class DeviceService {

    private final MonitoredPersonRepository monitoredPersonRepo;
    private final PairedDeviceRepository pairedDeviceRepo;
    private final PushTokenRepository pushTokenRepo;
    private final JwtService jwtService;

    public DeviceService(MonitoredPersonRepository monitoredPersonRepo,
                         PairedDeviceRepository pairedDeviceRepo,
                         PushTokenRepository pushTokenRepo,
                         JwtService jwtService) {
        this.monitoredPersonRepo = monitoredPersonRepo;
        this.pairedDeviceRepo    = pairedDeviceRepo;
        this.pushTokenRepo       = pushTokenRepo;
        this.jwtService          = jwtService;
    }

    @Transactional
    public DeviceDtos.PairResponse pair(DeviceDtos.PairRequest request) {
        var person = monitoredPersonRepo.findByPairingCode(request.pairingCode())
                .orElseThrow(() -> DomainExceptions.NotFoundException.of(
                        "Invalid or expired pairing code"));

        var device = pairedDeviceRepo
                .findByMonitoredPersonIdAndDeviceId(person.getId(), request.deviceId())
                .orElseGet(PairedDevice::new);

        device.setMonitoredPersonId(person.getId());
        device.setDeviceId(request.deviceId());
        device.setPlatform(request.platform());
        device.setActive(true);

        String deviceToken = jwtService.generateDeviceToken(person.getId(), request.deviceId());
        device.setDeviceTokenHash(hashToken(deviceToken));
        pairedDeviceRepo.save(device);

        // Invalidate pairingCode — single use only
        person.setPairingCode(null);
        monitoredPersonRepo.save(person);

        return new DeviceDtos.PairResponse(person.getId(), deviceToken);
    }

    private static String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    /**
     * Recovers the pairing for the authenticated MONITORED user.
     * Finds the MonitoredPerson linked to the user, then the active PairedDevice,
     * and re-issues a fresh device token (the original is only stored as a hash).
     *
     * Returns null if no active pairing exists for this user.
     */
    public DeviceDtos.MyPairingResponse recoverPairing(UUID monitoredUserId) {
        var person = monitoredPersonRepo.findByUserId(monitoredUserId)
                .orElse(null);
        if (person == null) {
            return null;
        }

        var device = pairedDeviceRepo.findFirstByMonitoredPersonIdAndActiveTrue(person.getId())
                .orElse(null);
        if (device == null) {
            return null;
        }

        // Re-issue a fresh device token (original JWT is not stored, only its hash)
        String freshToken = jwtService.generateDeviceToken(person.getId(), device.getDeviceId());
        device.setDeviceTokenHash(hashToken(freshToken));
        pairedDeviceRepo.save(device);

        return new DeviceDtos.MyPairingResponse(person.getId(), device.getDeviceId(), freshToken);
    }

    @Transactional
    public void registerPushToken(UUID userId, DeviceDtos.PushTokenRequest request) {
        var token = pushTokenRepo
                .findByUserIdAndDeviceId(userId, request.deviceId())
                .orElseGet(PushToken::new);

        token.setUserId(userId);
        token.setDeviceId(request.deviceId());
        token.setFcmToken(request.fcmToken());
        token.setPlatform(request.platform());
        token.setLocale(request.locale() != null ? request.locale() : DomainConstants.DEFAULT_LOCALE);
        token.setUpdatedAt(Instant.now());

        pushTokenRepo.save(token);
    }

    /**
     * Removes the caregiver's FCM registration for this device.
     * Idempotent: no-op if the token does not exist (spec §6.4 / T2c.10).
     */
    @Transactional
    public void unregisterPushToken(UUID userId, String deviceId) {
        pushTokenRepo.findByUserIdAndDeviceId(userId, deviceId)
                .ifPresent(pushTokenRepo::delete);
    }
}
