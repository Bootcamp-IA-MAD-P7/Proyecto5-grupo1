package com.sentilife.admin;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.alerts.Alert;
import com.sentilife.alerts.AlertRepository;
import com.sentilife.alerts.FeedbackLabel;
import com.sentilife.alerts.FeedbackLabelRepository;
import com.sentilife.config.DomainExceptions;
import com.sentilife.monitored.MonitoredPersonRepository;
import com.sentilife.telemetry.TelemetryWindowRepository;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Admin business logic — IT_ADMIN only.
 *
 * history:     global paginated view of alerts + feedback.
 * export:      labelled dataset (telemetry windows + feedback) for retraining.
 * listUsers:   all users with their roles and status.
 * setActive:   activate or deactivate a user.
 */
@Service
public class AdminService {

    private final AlertRepository alertRepository;
    private final FeedbackLabelRepository feedbackRepository;
    private final MonitoredPersonRepository monitoredPersonRepository;
    private final TelemetryWindowRepository telemetryRepository;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    public AdminService(AlertRepository alertRepository,
                        FeedbackLabelRepository feedbackRepository,
                        MonitoredPersonRepository monitoredPersonRepository,
                        TelemetryWindowRepository telemetryRepository,
                        UserRepository userRepository,
                        ObjectMapper objectMapper) {
        this.alertRepository           = alertRepository;
        this.feedbackRepository        = feedbackRepository;
        this.monitoredPersonRepository = monitoredPersonRepository;
        this.telemetryRepository       = telemetryRepository;
        this.userRepository            = userRepository;
        this.objectMapper              = objectMapper;
    }

    // ── History ───────────────────────────────────────────────────────────────

    /**
     * Global alert history with optional filters for the IT admin UI.
     *
     * @param monitoredPersonId when non-null, only alerts for that person
     * @param requireFeedback   when true, only alerts that already have feedback
     * @param feedbackLabel     optional TRUE_FALL | FALSE_ALARM (only with requireFeedback)
     */
    public Page<AdminDtos.HistoryEntry> getHistory(
            UUID monitoredPersonId,
            boolean requireFeedback,
            String feedbackLabel,
            Pageable pageable) {
        String normalizedLabel = normalizeFeedbackLabel(feedbackLabel, requireFeedback);
        var sorted = org.springframework.data.domain.PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Direction.DESC, "detectedAt"));
        return alertRepository
                .findForAdminHistory(
                        monitoredPersonId, requireFeedback, normalizedLabel, sorted)
                .map(this::toHistoryEntry);
    }

    public List<AdminDtos.MonitoredPersonOption> listMonitoredPersons() {
        return monitoredPersonRepository
                .findAll(Sort.by(Sort.Direction.ASC, "fullName"))
                .stream()
                .map(p -> new AdminDtos.MonitoredPersonOption(p.getId(), p.getFullName()))
                .collect(Collectors.toList());
    }

    private String normalizeFeedbackLabel(String feedbackLabel, boolean requireFeedback) {
        if (!requireFeedback || feedbackLabel == null || feedbackLabel.isBlank()) {
            return null;
        }
        String label = feedbackLabel.trim().toUpperCase();
        if (!"TRUE_FALL".equals(label) && !"FALSE_ALARM".equals(label)) {
            throw DomainExceptions.BadRequestException.of(
                    "feedbackLabel must be TRUE_FALL or FALSE_ALARM");
        }
        return label;
    }

    // ── Export labelled dataset ───────────────────────────────────────────────

    /**
     * Returns all telemetry windows that have a feedback label.
     * This is the dataset used to retrain the ML model.
     */
    public List<AdminDtos.ExportRow> exportLabelledDataset(Instant from, Instant to) {
        return feedbackRepository.findAll().stream()
                .filter(f -> {
                    if (f.getTelemetryWindowRef() == null) return false;
                    try {
                        UUID windowId = UUID.fromString(f.getTelemetryWindowRef());
                        return telemetryRepository.findById(windowId)
                                .map(w -> isInRange(w.getWindowStart(), from, to))
                                .orElse(false);
                    } catch (IllegalArgumentException e) {
                        return false;
                    }
                })
                .map(f -> {
                    UUID windowId = UUID.fromString(f.getTelemetryWindowRef());
                    return telemetryRepository.findById(windowId)
                            .map(w -> new AdminDtos.ExportRow(
                                    w.getId(),
                                    w.getMonitoredPersonId(),
                                    w.getWindowStart(),
                                    w.getWindowEnd(),
                                    w.getSampleRateHz(),
                                    serializeSamplesJson(w.getSamplesJson()),
                                    f.getLabel()
                            ))
                            .orElse(null);
                })
                .filter(row -> row != null)
                .collect(Collectors.toList());
    }

    // ── Users ─────────────────────────────────────────────────────────────────

    public Page<AdminDtos.UserSummary> listUsers(Pageable pageable) {
        return userRepository.findAll(pageable).map(this::toUserSummary);
    }

    @Transactional
    public AdminDtos.UserSummary setUserActive(UUID userId, AdminDtos.UserStatusRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> DomainExceptions.NotFoundException.of("User not found"));
        user.setActive(request.active());
        return toUserSummary(userRepository.save(user));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private AdminDtos.HistoryEntry toHistoryEntry(Alert a) {
        String personName = monitoredPersonRepository.findById(a.getMonitoredPersonId())
                .map(p -> p.getFullName())
                .orElse("Unknown");

        FeedbackLabel feedback = feedbackRepository.findByAlertId(a.getId()).orElse(null);

        return new AdminDtos.HistoryEntry(
                a.getId(), a.getMonitoredPersonId(), personName,
                a.getDetectedAt(), a.getConfidence(), a.getModelVersion(),
                a.getStatus(),
                feedback != null ? feedback.getLabel() : null,
                feedback != null ? feedback.getComment() : null
        );
    }

    private AdminDtos.UserSummary toUserSummary(User u) {
        return new AdminDtos.UserSummary(
                u.getId(), u.getEmail(), u.getFullName(),
                u.getRole(), u.getActive(), u.getCreatedAt());
    }

    private boolean isInRange(Instant timestamp, Instant from, Instant to) {
        if (from != null && timestamp.isBefore(from)) return false;
        if (to != null && timestamp.isAfter(to)) return false;
        return true;
    }

    private String serializeSamplesJson(java.util.Map<String, Object> samplesJson) {
        if (samplesJson == null || samplesJson.isEmpty()) {
            return "{}";
        }
        try {
            return objectMapper.writeValueAsString(samplesJson);
        } catch (JsonProcessingException e) {
            return "{}";
        }
    }
}
