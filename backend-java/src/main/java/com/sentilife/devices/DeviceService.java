package com.sentilife.devices;

import com.sentilife.monitored.MonitoredPersonRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.UUID;

/**
 * Lógica de negocio para vinculación de dispositivos y tokens push.
 *
 * pair: busca la persona por pairingCode, registra el dispositivo y
 *       devuelve un token de dispositivo para usar en /telemetry/windows.
 *
 * registerPushToken: registra o actualiza el token FCM del cuidador.
 *                    Idempotente: mismo userId + deviceId actualiza el token.
 */
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
        // 1. Buscar la persona por pairingCode
        var person = monitoredPersonRepo.findByPairingCode(request.pairingCode())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Código de vinculación inválido o expirado"));

        // 2. Registrar o actualizar el dispositivo
        var device = pairedDeviceRepo
                .findByMonitoredPersonIdAndDeviceId(person.getId(), request.deviceId())
                .orElseGet(PairedDevice::new);

        device.setMonitoredPersonId(person.getId());
        device.setDeviceId(request.deviceId());
        device.setPlatform(request.platform());
        device.setActive(true);
        pairedDeviceRepo.save(device);

        // 3. Invalidar el pairingCode (solo uso único)
        person.setPairingCode(null);
        monitoredPersonRepo.save(person);

        // TODO Fase 2: emitir JWT de dispositivo real con Spring Security
        // Por ahora devolvemos el monitoredPersonId como token provisional
        String deviceToken = person.getId().toString();

        return new DeviceDtos.PairResponse(person.getId(), deviceToken);
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
        token.setLocale(request.locale() != null ? request.locale() : "es");
        token.setUpdatedAt(Instant.now());

        pushTokenRepo.save(token);
    }
}
