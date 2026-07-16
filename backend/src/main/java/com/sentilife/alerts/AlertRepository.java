package com.sentilife.alerts;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
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

    /** Most recent alert for cooldown check (T2c.6) */
    Optional<Alert> findTopByMonitoredPersonIdOrderByDetectedAtDesc(UUID monitoredPersonId);

    /** Used for GDPR suppression — get alert IDs before deleting feedback */
    List<Alert> findByMonitoredPersonId(UUID monitoredPersonId);

    /** Used for GDPR suppression — delete all alerts for a person */
    void deleteByMonitoredPersonId(UUID monitoredPersonId);

    long countByMonitoredPersonId(UUID monitoredPersonId);

    /**
     * Admin history — optional person + feedback filters.
     * When {@code requireFeedback} is false, {@code feedbackLabel} is ignored.
     */
    @Query("""
            SELECT a FROM Alert a
            WHERE (:personId IS NULL OR a.monitoredPersonId = :personId)
              AND (
                :requireFeedback = false
                OR EXISTS (
                  SELECT 1 FROM FeedbackLabel f
                  WHERE f.alertId = a.id
                    AND (:feedbackLabel IS NULL OR f.label = :feedbackLabel)
                )
              )
            """)
    Page<Alert> findForAdminHistory(
            @Param("personId") UUID personId,
            @Param("requireFeedback") boolean requireFeedback,
            @Param("feedbackLabel") String feedbackLabel,
            Pageable pageable);
}
