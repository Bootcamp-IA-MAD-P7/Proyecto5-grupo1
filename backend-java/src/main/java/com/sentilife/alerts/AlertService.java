package com.sentilife.alerts;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.monitored.MonitoredPersonRepository;
import com.sentilife.notifications.AlertEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Business logic for alerts and caregiver feedback.
 *
 * createAlert: called by TelemetryService when fallDetected = true.
 * listAlerts:  returns paginated alerts for the caregiver's persons.
 * submitFeedback: caregiver confirms or dismisses an alert (TRUE_FALL / FALSE_ALARM).
 */
@Service
public class AlertService {

    private final AlertRepository alertRepository;
    private final FeedbackLabelRepository feedbackRepository;
    private final MonitoredPersonRepository monitoredPersonRepository;
    private final AlertEventPublisher alertEventPublisher;

    public AlertService(AlertRepository alertRepository,
                        FeedbackLabelRepository feedbackRepository,
                        MonitoredPersonRepository monitoredPersonRepository,
                        AlertEventPublisher alertEventPublisher) {
        this.alertRepository           = alertRepository;
        this.feedbackRepository        = feedbackRepository;
        this.monitoredPersonRepository = monitoredPersonRepository;
        this.alertEventPublisher       = alertEventPublisher;
    }

    /**
     * Creates an alert when a fall is detected.
     * Called internally by TelemetryService — not exposed as an HTTP endpoint.
     */
    @Transactional
    public Alert createAlert(UUID monitoredPersonId, double confidence,
                             String modelVersion, UUID windowId) {
        Alert alert = new Alert();
        alert.setMonitoredPersonId(monitoredPersonId);
        alert.setConfidence(BigDecimal.valueOf(confidence));
        alert.setModelVersion(modelVersion);
        alert.setStatus(DomainConstants.ALERT_PENDING);
        alert.setTelemetryWindowId(windowId);
        alert = alertRepository.save(alert);

        // Publish event for async push notification (ADR-07)
        alertEventPublisher.publishAlertCreated(
                alert.getId(), monitoredPersonId, confidence, modelVersion);

        return alert;
    }

    /**
     * Returns paginated alerts for all persons managed by the caregiver.
     * Optional filter by status.
     */
    public Page<AlertDtos.AlertResponse> listAlerts(UUID caregiverId, String status,
                                                    Pageable pageable) {
        return alertRepository
                .findByCaregiverIdAndStatus(caregiverId, status, pageable)
                .map(this::toResponse);
    }

    /**
     * Caregiver confirms or dismisses an alert and optionally adds a comment.
     * Creates a FeedbackLabel entry for the ML retraining pipeline.
     */
    @Transactional
    public AlertDtos.FeedbackResponse submitFeedback(UUID caregiverId, UUID alertId,
                                                     AlertDtos.FeedbackRequest request) {
        Alert alert = alertRepository.findById(alertId)
                .orElseThrow(() -> DomainExceptions.NotFoundException.of("Alert not found"));

        // Verify the alert belongs to one of the caregiver's persons
        monitoredPersonRepository.findById(alert.getMonitoredPersonId())
                .filter(p -> p.getCaregiverId().equals(caregiverId))
                .orElseThrow(() -> DomainExceptions.ForbiddenException.of(
                        "Access denied to this alert"));

        // Update alert status
        alert.setStatus(request.status());
        alert.setReviewedBy(caregiverId);
        alert.setReviewedAt(Instant.now());
        alertRepository.save(alert);

        // Create feedback label for ML retraining pipeline
        String label = DomainConstants.ALERT_CONFIRMED.equals(request.status())
                ? "TRUE_FALL" : "FALSE_ALARM";

        FeedbackLabel feedback = new FeedbackLabel();
        feedback.setAlertId(alertId);
        feedback.setLabel(label);
        feedback.setComment(request.comment());
        feedback.setTelemetryWindowRef(alert.getTelemetryWindowId() != null
                ? alert.getTelemetryWindowId().toString() : null);
        feedback.setCreatedBy(caregiverId);
        feedback = feedbackRepository.save(feedback);

        return new AlertDtos.FeedbackResponse(alertId, alert.getStatus(), feedback.getId());
    }

    private AlertDtos.AlertResponse toResponse(Alert a) {
        String personName = monitoredPersonRepository.findById(a.getMonitoredPersonId())
                .map(p -> p.getFullName())
                .orElse("Unknown");
        return new AlertDtos.AlertResponse(a.getId(), a.getMonitoredPersonId(),
                personName, a.getDetectedAt(), a.getConfidence(),
                a.getModelVersion(), a.getStatus());
    }
}
