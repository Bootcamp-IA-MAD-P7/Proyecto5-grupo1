package com.sentilife.monitored;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface MonitoredPersonRepository extends JpaRepository<MonitoredPerson, UUID> {

    Optional<MonitoredPerson> findByPairingCode(String pairingCode);

    Optional<MonitoredPerson> findByUserId(UUID userId);

    boolean existsByUserId(UUID userId);

    Page<MonitoredPerson> findByCaregiverId(UUID caregiverId, Pageable pageable);
}
