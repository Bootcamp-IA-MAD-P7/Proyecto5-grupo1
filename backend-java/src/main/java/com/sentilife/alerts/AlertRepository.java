package com.sentilife.alerts;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.UUID;

public interface AlertRepository extends JpaRepository<Alert, UUID> {

    /**
     * All alerts for a caregiver's persons, optionally filtered by status.
     * Used by GET /alerts
     */
    @Query("SELECT a FROM Alert a WHERE a.monitoredPersonId IN " +
           "(SELECT mp.id FROM MonitoredPerson mp WHERE mp.caregiverId = :caregiverId) " +
           "AND (:status IS NULL OR a.status = :status) " +
           "ORDER BY a.detectedAt DESC")
    Page<Alert> findByCaregiverIdAndStatus(
            @Param("caregiverId") UUID caregiverId,
            @Param("status") String status,
            Pageable pageable);
}
