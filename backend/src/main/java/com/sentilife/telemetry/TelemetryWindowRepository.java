package com.sentilife.telemetry;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data generates the implementation automatically.
 * Only the queries we need are declared here.
 */
public interface TelemetryWindowRepository extends JpaRepository<TelemetryWindow, UUID> {

    /**
     * Last window for a person — used by GET /telemetry/status/{id}
     */
    @Query("SELECT t FROM TelemetryWindow t WHERE t.monitoredPersonId = :personId " +
           "ORDER BY t.windowStart DESC LIMIT 1")
    Optional<TelemetryWindow> findLastByMonitoredPersonId(@Param("personId") UUID personId);

    /** Used for GDPR suppression — delete all telemetry windows for a person */
    void deleteByMonitoredPersonId(UUID monitoredPersonId);
}
