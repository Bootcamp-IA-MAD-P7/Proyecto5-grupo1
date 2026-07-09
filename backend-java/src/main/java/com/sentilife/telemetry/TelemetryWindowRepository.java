package com.sentilife.telemetry;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data genera la implementación automáticamente.
 * Solo declaramos las consultas que necesitamos.
 */
public interface TelemetryWindowRepository extends JpaRepository<TelemetryWindow, UUID> {

    /**
     * Última ventana de una persona — usada por GET /telemetry/status/{id}
     */
    @Query("SELECT t FROM TelemetryWindow t WHERE t.monitoredPersonId = :personId " +
           "ORDER BY t.windowStart DESC LIMIT 1")
    Optional<TelemetryWindow> findLastByMonitoredPersonId(@Param("personId") UUID personId);
}
