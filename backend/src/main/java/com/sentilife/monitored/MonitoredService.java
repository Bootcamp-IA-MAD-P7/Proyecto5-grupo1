package com.sentilife.monitored;

import com.sentilife.alerts.AlertRepository;
import com.sentilife.alerts.FeedbackLabelRepository;
import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.consent.Consent;
import com.sentilife.consent.ConsentRepository;
import com.sentilife.devices.PairedDeviceRepository;
import com.sentilife.telemetry.TelemetryWindowRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

/**
 * Business logic for monitored persons CRUD and GDPR consent management.
 *
 * Each CAREGIVER can only view and modify their own monitored persons.
 * The pairingCode is generated on creation — 6-char alphanumeric prefixed with "SL-".
 */
@Service
public class MonitoredService {

    private final MonitoredPersonRepository repository;
    private final ConsentRepository consentRepository;
    private final AlertRepository alertRepository;
    private final FeedbackLabelRepository feedbackRepository;
    private final TelemetryWindowRepository telemetryRepository;
    private final PairedDeviceRepository pairedDeviceRepository;

    public MonitoredService(MonitoredPersonRepository repository,
                            ConsentRepository consentRepository,
                            AlertRepository alertRepository,
                            FeedbackLabelRepository feedbackRepository,
                            TelemetryWindowRepository telemetryRepository,
                            PairedDeviceRepository pairedDeviceRepository) {
        this.repository            = repository;
        this.consentRepository     = consentRepository;
        this.alertRepository       = alertRepository;
        this.feedbackRepository    = feedbackRepository;
        this.telemetryRepository   = telemetryRepository;
        this.pairedDeviceRepository = pairedDeviceRepository;
    }

    @Transactional
    public MonitoredDtos.MonitoredResponse create(UUID caregiverId,
                                                  MonitoredDtos.MonitoredRequest request) {
        MonitoredPerson person = new MonitoredPerson();
        fillFromRequest(person, request);
        person.setCaregiverId(caregiverId);
        person.setPairingCode(generatePairingCode());
        return toResponse(repository.save(person));
    }

    public Page<MonitoredDtos.MonitoredResponse> listByCaegiver(UUID caregiverId, Pageable pageable) {
        return repository.findByCaregiverId(caregiverId, pageable).map(this::toResponse);
    }

    public MonitoredDtos.MonitoredResponse getById(UUID caregiverId, UUID personId) {
        return toResponse(findOwned(caregiverId, personId));
    }

    @Transactional
    public MonitoredDtos.MonitoredResponse update(UUID caregiverId, UUID personId,
                                                  MonitoredDtos.MonitoredRequest request) {
        MonitoredPerson person = findOwned(caregiverId, personId);
        fillFromRequest(person, request);
        return toResponse(repository.save(person));
    }

    @Transactional
    public void delete(UUID caregiverId, UUID personId) {
        MonitoredPerson person = findOwned(caregiverId, personId);

        // GDPR full suppression — order matters due to FK constraints:
        // 1. feedback_labels (references alerts)
        alertRepository.findByMonitoredPersonId(personId)
                .forEach(a -> feedbackRepository.deleteByAlertId(a.getId()));
        // 2. alerts
        alertRepository.deleteByMonitoredPersonId(personId);
        // 3. telemetry windows
        telemetryRepository.deleteByMonitoredPersonId(personId);
        // 4. paired devices
        pairedDeviceRepository.deleteByMonitoredPersonId(personId);
        // 5. consents
        consentRepository.deleteByMonitoredPersonId(personId);
        // 6. the person itself
        repository.delete(person);
    }

    @Transactional
    public MonitoredDtos.ConsentResponse acceptConsent(UUID caregiverId, UUID personId,
                                                       MonitoredDtos.ConsentRequest request) {
        findOwned(caregiverId, personId);

        // Revoke any existing active consent before creating a new one
        consentRepository.findByMonitoredPersonIdAndStatus(personId, DomainConstants.CONSENT_ACTIVE)
                .ifPresent(c -> {
                    c.setStatus(DomainConstants.CONSENT_REVOKED);
                    c.setRevokedAt(Instant.now());
                    consentRepository.save(c);
                });

        Consent consent = new Consent();
        consent.setMonitoredPersonId(personId);
        consent.setPolicyVersion(request.policyVersion());
        consent.setStatus(DomainConstants.CONSENT_ACTIVE);
        return toConsentResponse(consentRepository.save(consent));
    }

    @Transactional
    public MonitoredDtos.ConsentResponse revokeConsent(UUID caregiverId, UUID personId) {
        findOwned(caregiverId, personId);

        Consent consent = consentRepository
                .findByMonitoredPersonIdAndStatus(personId, DomainConstants.CONSENT_ACTIVE)
                .orElseThrow(() -> DomainExceptions.NotFoundException.of("No active consent found"));

        consent.setStatus(DomainConstants.CONSENT_REVOKED);
        consent.setRevokedAt(Instant.now());
        return toConsentResponse(consentRepository.save(consent));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private MonitoredPerson findOwned(UUID caregiverId, UUID personId) {
        MonitoredPerson person = repository.findById(personId)
                .orElseThrow(() -> DomainExceptions.NotFoundException.of("Person not found"));
        if (!person.getCaregiverId().equals(caregiverId)) {
            throw DomainExceptions.ForbiddenException.of("Access denied to this person");
        }
        return person;
    }

    private void fillFromRequest(MonitoredPerson p, MonitoredDtos.MonitoredRequest r) {
        p.setFullName(r.fullName());
        p.setBirthDate(r.birthDate());
        p.setSex(r.sex());
        p.setWeightKg(r.weightKg());
        p.setHeightCm(r.heightCm());
        p.setEmergencyContact(r.emergencyContact());
    }

    private MonitoredDtos.MonitoredResponse toResponse(MonitoredPerson person) {
        String consentStatus = consentRepository
                .existsByMonitoredPersonIdAndStatus(person.getId(), DomainConstants.CONSENT_ACTIVE)
                ? DomainConstants.CONSENT_ACTIVE : DomainConstants.CONSENT_PENDING;
        return MonitoredDtos.MonitoredResponse.from(person, consentStatus,
                DomainConstants.MONITORING_INACTIVE);
    }

    private MonitoredDtos.ConsentResponse toConsentResponse(Consent c) {
        return new MonitoredDtos.ConsentResponse(c.getId(), c.getMonitoredPersonId(),
                c.getPolicyVersion(), c.getStatus(), c.getAcceptedAt(), c.getRevokedAt());
    }

    private String generatePairingCode() {
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        StringBuilder sb = new StringBuilder("SL-");
        for (int i = 0; i < 6; i++) {
            sb.append(chars.charAt((int) (Math.random() * chars.length())));
        }
        return sb.toString();
    }
}
