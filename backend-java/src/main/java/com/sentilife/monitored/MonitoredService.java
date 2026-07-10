package com.sentilife.monitored;

import com.sentilife.consent.Consent;
import com.sentilife.consent.ConsentRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.UUID;

/**
 * CRUD de personas monitorizadas + gestión de consentimiento GDPR.
 *
 * Cada CAREGIVER solo puede ver y modificar sus propias personas.
 * El pairingCode se genera al crear — UUID corto de 6 chars alfanuméricos.
 */
@Service
public class MonitoredService {

    private final MonitoredPersonRepository repository;
    private final ConsentRepository consentRepository;

    public MonitoredService(MonitoredPersonRepository repository,
                            ConsentRepository consentRepository) {
        this.repository        = repository;
        this.consentRepository = consentRepository;
    }

    // ── CRUD ─────────────────────────────────────────────────────────────────

    @Transactional
    public MonitoredDtos.MonitoredResponse create(UUID caregiverId,
                                                  MonitoredDtos.MonitoredRequest request) {
        MonitoredPerson person = new MonitoredPerson();
        fillFromRequest(person, request);
        person.setCaregiverId(caregiverId);
        person.setPairingCode(generatePairingCode());
        person = repository.save(person);
        return toResponse(person);
    }

    public Page<MonitoredDtos.MonitoredResponse> listByCaegiver(UUID caregiverId,
                                                                Pageable pageable) {
        return repository.findByCaregiverId(caregiverId, pageable)
                .map(this::toResponse);
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
        // Supresión GDPR: borrar consentimientos y luego la persona
        consentRepository.deleteByMonitoredPersonId(personId);
        repository.delete(person);
    }

    // ── Consentimiento ────────────────────────────────────────────────────────

    @Transactional
    public MonitoredDtos.ConsentResponse acceptConsent(UUID caregiverId, UUID personId,
                                                       MonitoredDtos.ConsentRequest request) {
        findOwned(caregiverId, personId);  // verifica que pertenece al cuidador

        // Revocar cualquier consentimiento activo previo
        consentRepository.findByMonitoredPersonIdAndStatus(personId, "ACTIVE")
                .ifPresent(c -> {
                    c.setStatus("REVOKED");
                    c.setRevokedAt(Instant.now());
                    consentRepository.save(c);
                });

        Consent consent = new Consent();
        consent.setMonitoredPersonId(personId);
        consent.setPolicyVersion(request.policyVersion());
        consent.setStatus("ACTIVE");
        consent = consentRepository.save(consent);

        return toConsentResponse(consent);
    }

    @Transactional
    public MonitoredDtos.ConsentResponse revokeConsent(UUID caregiverId, UUID personId) {
        findOwned(caregiverId, personId);

        Consent consent = consentRepository
                .findByMonitoredPersonIdAndStatus(personId, "ACTIVE")
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "No hay consentimiento activo"));

        consent.setStatus("REVOKED");
        consent.setRevokedAt(Instant.now());
        return toConsentResponse(consentRepository.save(consent));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private MonitoredPerson findOwned(UUID caregiverId, UUID personId) {
        MonitoredPerson person = repository.findById(personId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Persona no encontrada"));
        if (!person.getCaregiverId().equals(caregiverId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "No tienes acceso a esta persona");
        }
        return person;
    }

    private void fillFromRequest(MonitoredPerson person, MonitoredDtos.MonitoredRequest req) {
        person.setFullName(req.fullName());
        person.setBirthDate(req.birthDate());
        person.setSex(req.sex());
        person.setWeightKg(req.weightKg());
        person.setHeightCm(req.heightCm());
        person.setEmergencyContact(req.emergencyContact());
    }

    private MonitoredDtos.MonitoredResponse toResponse(MonitoredPerson person) {
        String consentStatus = consentRepository
                .existsByMonitoredPersonIdAndStatus(person.getId(), "ACTIVE")
                ? "ACTIVE" : "PENDING";
        return MonitoredDtos.MonitoredResponse.from(person, consentStatus, "INACTIVE");
    }

    private MonitoredDtos.ConsentResponse toConsentResponse(Consent c) {
        return new MonitoredDtos.ConsentResponse(
                c.getId(), c.getMonitoredPersonId(), c.getPolicyVersion(),
                c.getStatus(), c.getAcceptedAt(), c.getRevokedAt());
    }

    private String generatePairingCode() {
        // Formato SL-XXXXXX (6 chars alfanuméricos en mayúsculas)
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        StringBuilder sb = new StringBuilder("SL-");
        for (int i = 0; i < 6; i++) {
            sb.append(chars.charAt((int) (Math.random() * chars.length())));
        }
        return sb.toString();
    }
}
