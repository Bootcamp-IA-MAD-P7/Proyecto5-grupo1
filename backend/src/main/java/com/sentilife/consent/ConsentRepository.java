package com.sentilife.consent;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface ConsentRepository extends JpaRepository<Consent, UUID> {

    Optional<Consent> findByMonitoredPersonIdAndStatus(UUID monitoredPersonId, String status);

    boolean existsByMonitoredPersonIdAndStatus(UUID monitoredPersonId, String status);

    void deleteByMonitoredPersonId(UUID monitoredPersonId);

    long countByMonitoredPersonId(UUID monitoredPersonId);
}
