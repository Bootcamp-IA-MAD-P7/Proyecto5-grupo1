package com.sentilife.devices;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PairedDeviceRepository extends JpaRepository<PairedDevice, UUID> {

    Optional<PairedDevice> findByMonitoredPersonIdAndDeviceId(UUID monitoredPersonId, String deviceId);

    boolean existsByMonitoredPersonId(UUID monitoredPersonId);

    /** Used for GDPR suppression */
    void deleteByMonitoredPersonId(UUID monitoredPersonId);
}
