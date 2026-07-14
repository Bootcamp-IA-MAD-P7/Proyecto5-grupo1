package com.sentilife.monitored;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface MonitoredPersonRepository extends JpaRepository<MonitoredPerson, UUID> {

    Optional<MonitoredPerson> findByPairingCode(String pairingCode);

    Optional<MonitoredPerson> findByUserId(UUID userId);

    boolean existsByUserId(UUID userId);

    Page<MonitoredPerson> findByCaregiverId(UUID caregiverId, Pageable pageable);

    /** Pessimistic lock for atomic alert aggregation (T2c.6) */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT mp FROM MonitoredPerson mp WHERE mp.id = :id")
    Optional<MonitoredPerson> findByIdForUpdate(@Param("id") UUID id);
}
