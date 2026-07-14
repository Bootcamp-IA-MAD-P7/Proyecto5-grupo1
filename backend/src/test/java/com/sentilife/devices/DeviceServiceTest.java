package com.sentilife.devices;

import com.sentilife.config.JwtService;
import com.sentilife.monitored.MonitoredPersonRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for push token lifecycle — T2c.10 / spec §6.4.
 */
@ExtendWith(MockitoExtension.class)
class DeviceServiceTest {

    @Mock MonitoredPersonRepository monitoredPersonRepo;
    @Mock PairedDeviceRepository pairedDeviceRepo;
    @Mock PushTokenRepository pushTokenRepo;
    @Mock JwtService jwtService;

    DeviceService service;

    private final UUID userId = UUID.randomUUID();
    private final String deviceId = "android-test-001";

    @BeforeEach
    void setUp() {
        service = new DeviceService(monitoredPersonRepo, pairedDeviceRepo, pushTokenRepo, jwtService);
    }

    @Test
    void unregisterPushToken_deletesExistingToken() {
        PushToken token = new PushToken();
        token.setUserId(userId);
        token.setDeviceId(deviceId);
        when(pushTokenRepo.findByUserIdAndDeviceId(userId, deviceId)).thenReturn(Optional.of(token));

        service.unregisterPushToken(userId, deviceId);

        verify(pushTokenRepo).delete(token);
    }

    @Test
    void unregisterPushToken_idempotentWhenMissing() {
        when(pushTokenRepo.findByUserIdAndDeviceId(userId, deviceId)).thenReturn(Optional.empty());

        service.unregisterPushToken(userId, deviceId);

        verify(pushTokenRepo, never()).delete(any());
    }
}
