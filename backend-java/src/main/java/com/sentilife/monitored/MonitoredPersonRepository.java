package com.sentilife.monitored;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface MonitoredPersonRepository extends JpaRepository<MonitoredPerson, UUID> {

    Optional<MonitoredPerson> findByPairingCode(String pairingCode);
}
