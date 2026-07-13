package com.sentilife.monitored;

import com.sentilife.alerts.AlertRepository;
import com.sentilife.alerts.FeedbackLabelRepository;
import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.consent.Consent;
import com.sentilife.consent.ConsentRepository;
import com.sentilife.devices.PairedDeviceRepository;
import com.sentilife.telemetry.TelemetryWindowRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for MonitoredService — consent and access control.
 */
@ExtendWith(MockitoExtension.class)
class MonitoredServiceTest {

    @Mock MonitoredPersonRepository repository;
    @Mock ConsentRepository consentRepository;
    @Mock AlertRepository alertRepository;
    @Mock FeedbackLabelRepository feedbackRepository;
    @Mock TelemetryWindowRepository telemetryRepository;
    @Mock PairedDeviceRepository pairedDeviceRepository;

    @InjectMocks MonitoredService service;

    private UUID caregiverId;
    private UUID personId;
    private MonitoredPerson person;

    @BeforeEach
    void setUp() {
        caregiverId = UUID.randomUUID();
        personId    = UUID.randomUUID();

        person = new MonitoredPerson();
        person.setCaregiverId(caregiverId);
        person.setFullName("Manuel Pérez");
        person.setBirthDate(LocalDate.of(1948, 3, 12));
        person.setSex("M");
    }

    // ── access control ────────────────────────────────────────────────────────

    @Test
    void getById_differentCaregiver_throwsForbidden() {
        UUID otherCaregiver = UUID.randomUUID();
        when(repository.findById(personId)).thenReturn(Optional.of(person));

        assertThatThrownBy(() -> service.getById(otherCaregiver, personId))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);
    }

    @Test
    void getById_personNotFound_throwsNotFound() {
        when(repository.findById(personId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getById(caregiverId, personId))
                .isInstanceOf(DomainExceptions.NotFoundException.class);
    }

    // ── consent ───────────────────────────────────────────────────────────────

    @Test
    void acceptConsent_createsActiveConsent() {
        when(repository.findById(personId)).thenReturn(Optional.of(person));
        when(consentRepository.findByMonitoredPersonIdAndStatus(personId,
                DomainConstants.CONSENT_ACTIVE)).thenReturn(Optional.empty());

        Consent saved = new Consent();
        saved.setMonitoredPersonId(personId);
        saved.setPolicyVersion("1.0-es");
        saved.setStatus(DomainConstants.CONSENT_ACTIVE);
        when(consentRepository.save(any())).thenReturn(saved);

        var result = service.acceptConsent(caregiverId, personId,
                new MonitoredDtos.ConsentRequest("1.0-es", "MONITORED"));

        assertThat(result.status()).isEqualTo(DomainConstants.CONSENT_ACTIVE);
        verify(consentRepository).save(any());
    }

    @Test
    void acceptConsent_revokesExistingBeforeCreating() {
        when(repository.findById(personId)).thenReturn(Optional.of(person));

        Consent existing = new Consent();
        existing.setStatus(DomainConstants.CONSENT_ACTIVE);
        when(consentRepository.findByMonitoredPersonIdAndStatus(personId,
                DomainConstants.CONSENT_ACTIVE)).thenReturn(Optional.of(existing));

        Consent saved = new Consent();
        saved.setMonitoredPersonId(personId);
        saved.setPolicyVersion("1.1-es");
        saved.setStatus(DomainConstants.CONSENT_ACTIVE);
        when(consentRepository.save(any())).thenReturn(saved);

        service.acceptConsent(caregiverId, personId,
                new MonitoredDtos.ConsentRequest("1.1-es", "MONITORED"));

        // Verify the old consent was revoked
        assertThat(existing.getStatus()).isEqualTo(DomainConstants.CONSENT_REVOKED);
        verify(consentRepository, times(2)).save(any());
    }

    @Test
    void acceptConsentByMonitored_withoutPairing_throwsForbidden() {
        when(repository.existsById(personId)).thenReturn(true);
        when(pairedDeviceRepository.existsByMonitoredPersonId(personId)).thenReturn(false);

        assertThatThrownBy(() -> service.acceptConsentByMonitored(personId,
                new MonitoredDtos.ConsentRequest("1.0-es", "MONITORED")))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);
    }

    @Test
    void acceptConsentByMonitored_withPairing_createsActiveConsent() {
        when(repository.existsById(personId)).thenReturn(true);
        when(pairedDeviceRepository.existsByMonitoredPersonId(personId)).thenReturn(true);
        when(consentRepository.findByMonitoredPersonIdAndStatus(personId,
                DomainConstants.CONSENT_ACTIVE)).thenReturn(Optional.empty());

        Consent saved = new Consent();
        saved.setMonitoredPersonId(personId);
        saved.setPolicyVersion("1.0-es");
        saved.setStatus(DomainConstants.CONSENT_ACTIVE);
        when(consentRepository.save(any())).thenReturn(saved);

        var result = service.acceptConsentByMonitored(personId,
                new MonitoredDtos.ConsentRequest("1.0-es", "MONITORED"));

        assertThat(result.status()).isEqualTo(DomainConstants.CONSENT_ACTIVE);
        verify(consentRepository).save(any());
    }

    @Test
    void revokeConsent_noActiveConsent_throwsNotFound() {
        when(repository.findById(personId)).thenReturn(Optional.of(person));
        when(consentRepository.findByMonitoredPersonIdAndStatus(personId,
                DomainConstants.CONSENT_ACTIVE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.revokeConsent(caregiverId, personId))
                .isInstanceOf(DomainExceptions.NotFoundException.class);
    }

    // ── GDPR delete ───────────────────────────────────────────────────────────

    @Test
    void delete_callsAllGdprRepositories() {
        when(repository.findById(personId)).thenReturn(Optional.of(person));
        when(alertRepository.findByMonitoredPersonId(personId)).thenReturn(java.util.List.of());

        service.delete(caregiverId, personId);

        verify(alertRepository).deleteByMonitoredPersonId(personId);
        verify(telemetryRepository).deleteByMonitoredPersonId(personId);
        verify(pairedDeviceRepository).deleteByMonitoredPersonId(personId);
        verify(consentRepository).deleteByMonitoredPersonId(personId);
        verify(repository).delete(person);
    }
}
