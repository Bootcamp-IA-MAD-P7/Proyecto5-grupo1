package com.sentilife.devices;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.monitored.MonitoredPersonRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class DeviceService {

    private final MonitoredPersonRepository monitoredPersonRepo;
    private final PairedDeviceRepository pairedDeviceRepo;
    private final PushTokenRepository pushTokenRepo;

    public DeviceService(MonitoredPersonRepository monitoredPersonRepo,
                         PairedDeviceRepository pairedDeviceRepo,
                         PushTokenRepository pushTokenRepo) {
        this.monitoredPersonRepo = monitoredPersonRepo;
        this.pairedDeviceRepo    = pairedDeviceRepo;
        this.pushTokenRepo       = pushTokenRepo;
    }

    @Transactional
    public DeviceDtos.PairResponse pair(DeviceDtos.PairRequest request) {
        var person = monitoredPersonRepo.findByPairingCode(request.pairingCode())
                .orElseThrow(() -> DomainExceptions.NotFoundException.of(
                        "Código de vinculación inválido o expirado"));

        var device = pairedDeviceRepo
                .findByMonitoredPersonIdAndDeviceId(person.getId(), request.deviceId())
                .orElseGet(PairedDevice::new);

        device.setMonitoredPersonId(person.getId());
        device.setDeviceId(request.deviceId());
        device.setPlatform(request.platform());
        device.setActive(true);
        pairedDeviceRepo.save(device);

        // Invalidar pairingCode — uso único
        person.setPairingCode(null);
        monitoredPersonRepo.save(person);

        // TODO Fase 2: JWT de dispositivo real
        return new DeviceDtos.PairResponse(person.getId(), person.getId().toString());
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
}
