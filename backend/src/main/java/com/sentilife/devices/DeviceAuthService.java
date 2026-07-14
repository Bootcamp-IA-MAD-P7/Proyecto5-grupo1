package com.sentilife.devices;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.config.JwtService;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Validates device bearer tokens for POST /telemetry/windows — T2c.11.
 */
@Service
public class DeviceAuthService {

    private final JwtService jwtService;
    private final PairedDeviceRepository pairedDeviceRepository;

    public DeviceAuthService(JwtService jwtService,
                             PairedDeviceRepository pairedDeviceRepository) {
        this.jwtService = jwtService;
        this.pairedDeviceRepository = pairedDeviceRepository;
    }

    public void validateForIngest(String authorizationHeader,
                                  UUID monitoredPersonId,
                                  String deviceId) {
        String token = extractBearer(authorizationHeader);
        if (token == null) {
            throw DomainExceptions.UnauthorizedException.of("Missing device token");
        }
        if (!jwtService.isValid(token)) {
            throw DomainExceptions.UnauthorizedException.of("Invalid device token");
        }
        if (!DomainConstants.TOKEN_DEVICE.equals(jwtService.extractType(token))) {
            throw DomainExceptions.UnauthorizedException.of("Invalid token type");
        }
        if (!jwtService.extractMonitoredPersonId(token).equals(monitoredPersonId)) {
            throw DomainExceptions.ForbiddenException.of("Device token does not match person");
        }
        if (!jwtService.extractDeviceId(token).equals(deviceId)) {
            throw DomainExceptions.ForbiddenException.of("Device token does not match device");
        }

        pairedDeviceRepository.findByMonitoredPersonIdAndDeviceId(monitoredPersonId, deviceId)
                .filter(device -> Boolean.TRUE.equals(device.getActive()))
                .orElseThrow(() -> DomainExceptions.ForbiddenException.of(
                        "No active pairing for this device"));
    }

    private String extractBearer(String header) {
        if (header == null || !header.startsWith(DomainConstants.BEARER_PREFIX)) {
            return null;
        }
        String token = header.substring(DomainConstants.BEARER_PREFIX.length()).trim();
        return token.isEmpty() ? null : token;
    }
}
