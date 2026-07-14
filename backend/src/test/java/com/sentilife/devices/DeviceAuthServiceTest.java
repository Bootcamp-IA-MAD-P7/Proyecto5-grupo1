package com.sentilife.devices;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.config.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Unit tests for device bearer validation on telemetry ingest — T2c.11.
 */
@ExtendWith(MockitoExtension.class)
class DeviceAuthServiceTest {

    @Mock JwtService jwtService;
    @Mock PairedDeviceRepository pairedDeviceRepository;

    DeviceAuthService service;

    private final UUID personId = UUID.randomUUID();
    private final String deviceId = "android-test-001";
    private final String validToken = "valid-device-jwt";

    @BeforeEach
    void setUp() {
        service = new DeviceAuthService(jwtService, pairedDeviceRepository);
    }

    @Test
    void missingAuthorization_throwsUnauthorized() {
        assertThatThrownBy(() -> service.validateForIngest(null, personId, deviceId))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);

        verifyNoInteractions(jwtService, pairedDeviceRepository);
    }

    @Test
    void invalidToken_throwsUnauthorized() {
        when(jwtService.isValid(validToken)).thenReturn(false);

        assertThatThrownBy(() -> service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);

        verifyNoInteractions(pairedDeviceRepository);
    }

    @Test
    void userAccessToken_throwsUnauthorized() {
        when(jwtService.isValid(validToken)).thenReturn(true);
        when(jwtService.extractType(validToken)).thenReturn(DomainConstants.TOKEN_ACCESS);

        assertThatThrownBy(() -> service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);

        verifyNoInteractions(pairedDeviceRepository);
    }

    @Test
    void wrongMonitoredPersonId_throwsForbidden() {
        when(jwtService.isValid(validToken)).thenReturn(true);
        when(jwtService.extractType(validToken)).thenReturn(DomainConstants.TOKEN_DEVICE);
        when(jwtService.extractMonitoredPersonId(validToken)).thenReturn(UUID.randomUUID());

        assertThatThrownBy(() -> service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);

        verifyNoInteractions(pairedDeviceRepository);
    }

    @Test
    void wrongDeviceId_throwsForbidden() {
        when(jwtService.isValid(validToken)).thenReturn(true);
        when(jwtService.extractType(validToken)).thenReturn(DomainConstants.TOKEN_DEVICE);
        when(jwtService.extractMonitoredPersonId(validToken)).thenReturn(personId);
        when(jwtService.extractDeviceId(validToken)).thenReturn("other-device");

        assertThatThrownBy(() -> service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);

        verifyNoInteractions(pairedDeviceRepository);
    }

    @Test
    void inactivePairing_throwsForbidden() {
        stubValidDeviceToken(personId, deviceId);
        PairedDevice inactive = new PairedDevice();
        inactive.setActive(false);
        when(pairedDeviceRepository.findByMonitoredPersonIdAndDeviceId(personId, deviceId))
                .thenReturn(Optional.of(inactive));

        assertThatThrownBy(() -> service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);
    }

    @Test
    void missingPairing_throwsForbidden() {
        stubValidDeviceToken(personId, deviceId);
        when(pairedDeviceRepository.findByMonitoredPersonIdAndDeviceId(personId, deviceId))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);
    }

    @Test
    void validTokenAndActivePairing_passes() {
        stubValidDeviceToken(personId, deviceId);
        PairedDevice active = new PairedDevice();
        active.setActive(true);
        when(pairedDeviceRepository.findByMonitoredPersonIdAndDeviceId(personId, deviceId))
                .thenReturn(Optional.of(active));

        service.validateForIngest(
                DomainConstants.BEARER_PREFIX + validToken, personId, deviceId);
    }

    private void stubValidDeviceToken(UUID claimPersonId, String claimDeviceId) {
        when(jwtService.isValid(validToken)).thenReturn(true);
        when(jwtService.extractType(validToken)).thenReturn(DomainConstants.TOKEN_DEVICE);
        when(jwtService.extractMonitoredPersonId(validToken)).thenReturn(claimPersonId);
        when(jwtService.extractDeviceId(validToken)).thenReturn(claimDeviceId);
    }
}
