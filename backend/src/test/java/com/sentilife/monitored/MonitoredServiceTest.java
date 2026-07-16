package com.sentilife.monitored;

import com.sentilife.alerts.AlertRepository;
import com.sentilife.alerts.FeedbackLabelRepository;
import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.consent.Consent;
import com.sentilife.consent.ConsentRepository;
import com.sentilife.devices.PairedDeviceRepository;
import com.sentilife.notifications.CaregiverEventPublisher;
import com.sentilife.telemetry.TelemetryWindow;
import com.sentilife.telemetry.TelemetryWindowRepository;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
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
    @Mock UserRepository userRepository;
    @Mock CaregiverEventPublisher caregiverEventPublisher;

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
    void create_resolvesNormalizedMonitoredEmailAndLinksUser() {
        UUID monitoredUserId = UUID.randomUUID();
        User monitoredUser = mock(User.class);
        when(monitoredUser.getId()).thenReturn(monitoredUserId);
        when(monitoredUser.getEmail()).thenReturn("monitored@test.com");
        when(monitoredUser.getFullName()).thenReturn("Nombre De Cuenta");
        when(monitoredUser.getRole()).thenReturn(DomainConstants.ROLE_MONITORED);
        when(monitoredUser.getActive()).thenReturn(true);
        when(userRepository.findByEmailIgnoreCase("monitored@test.com"))
                .thenReturn(Optional.of(monitoredUser));
        when(userRepository.findById(monitoredUserId))
                .thenReturn(Optional.of(monitoredUser));
        when(repository.save(any(MonitoredPerson.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        var result = service.create(caregiverId, new MonitoredDtos.MonitoredRequest(
                "  MONITORED@Test.COM  ",
                "Manuel Pérez",
                LocalDate.of(1948, 3, 12),
                "M",
                new BigDecimal("78.5"),
                new BigDecimal("172"),
                null));

        verify(userRepository).findByEmailIgnoreCase("monitored@test.com");
        verify(repository).save(argThat(saved ->
                monitoredUserId.equals(saved.getUserId())));
        assertThat(result.userId()).isEqualTo(monitoredUserId);
        assertThat(result.userEmail()).isEqualTo("monitored@test.com");
        assertThat(result.fullName()).isEqualTo("Nombre De Cuenta");
    }

    @Test
    void lookupLinkableAccount_returnsMonitoredUserSummary() {
        UUID monitoredUserId = UUID.randomUUID();
        User monitoredUser = mock(User.class);
        when(monitoredUser.getEmail()).thenReturn("monitored@test.com");
        when(monitoredUser.getFullName()).thenReturn("Nombre De Cuenta");
        when(monitoredUser.getRole()).thenReturn(DomainConstants.ROLE_MONITORED);
        when(monitoredUser.getActive()).thenReturn(true);
        when(userRepository.findByEmailIgnoreCase("monitored@test.com"))
                .thenReturn(Optional.of(monitoredUser));
        when(repository.existsByUserId(monitoredUserId)).thenReturn(false);
        when(monitoredUser.getId()).thenReturn(monitoredUserId);

        var result = service.lookupLinkableAccount("monitored@test.com");

        assertThat(result.email()).isEqualTo("monitored@test.com");
        assertThat(result.fullName()).isEqualTo("Nombre De Cuenta");
        assertThat(result.active()).isTrue();
        assertThat(result.alreadyLinked()).isFalse();
    }

    @Test
    void create_rejectsUnknownMonitoredEmail() {
        when(userRepository.findByEmailIgnoreCase("missing@test.com"))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.create(caregiverId,
                monitoredRequest("missing@test.com")))
                .isInstanceOf(DomainExceptions.NotFoundException.class);

        verify(repository, never()).save(any());
    }

    @Test
    void create_rejectsUserWithNonMonitoredRole() {
        User caregiverUser = mock(User.class);
        when(caregiverUser.getRole()).thenReturn(DomainConstants.ROLE_CAREGIVER);
        when(userRepository.findByEmailIgnoreCase("caregiver@test.com"))
                .thenReturn(Optional.of(caregiverUser));

        assertThatThrownBy(() -> service.create(caregiverId,
                monitoredRequest("caregiver@test.com")))
                .isInstanceOf(DomainExceptions.BadRequestException.class)
                .hasMessageContaining("MONITORED");

        verify(repository, never()).save(any());
    }

    @Test
    void create_rejectsInactiveMonitoredUser() {
        User inactiveUser = mock(User.class);
        when(inactiveUser.getRole()).thenReturn(DomainConstants.ROLE_MONITORED);
        when(inactiveUser.getActive()).thenReturn(false);
        when(userRepository.findByEmailIgnoreCase("inactive@test.com"))
                .thenReturn(Optional.of(inactiveUser));

        assertThatThrownBy(() -> service.create(caregiverId,
                monitoredRequest("inactive@test.com")))
                .isInstanceOf(DomainExceptions.BadRequestException.class)
                .hasMessageContaining("active");

        verify(repository, never()).save(any());
    }

    @Test
    void create_rejectsAlreadyLinkedMonitoredUser() {
        UUID monitoredUserId = UUID.randomUUID();
        User linkedUser = mock(User.class);
        when(linkedUser.getId()).thenReturn(monitoredUserId);
        when(linkedUser.getRole()).thenReturn(DomainConstants.ROLE_MONITORED);
        when(linkedUser.getActive()).thenReturn(true);
        when(userRepository.findByEmailIgnoreCase("linked@test.com"))
                .thenReturn(Optional.of(linkedUser));
        when(repository.existsByUserId(monitoredUserId)).thenReturn(true);

        assertThatThrownBy(() -> service.create(caregiverId,
                monitoredRequest("linked@test.com")))
                .isInstanceOf(DomainExceptions.ConflictException.class)
                .hasMessageContaining("already linked");

        verify(repository, never()).save(any());
    }

    @Test
    void getByMonitoredUserId_returnsLinkedProfile() {
        UUID monitoredUserId = UUID.randomUUID();
        person.setUserId(monitoredUserId);
        User monitoredUser = mock(User.class);
        when(monitoredUser.getEmail()).thenReturn("monitored@test.com");
        MonitoredPerson linked = spy(person);
        doReturn(personId).when(linked).getId();
        doReturn(Instant.now()).when(linked).getCreatedAt();
        when(repository.findByUserId(monitoredUserId)).thenReturn(Optional.of(linked));
        when(userRepository.findById(monitoredUserId)).thenReturn(Optional.of(monitoredUser));
        when(consentRepository.existsByMonitoredPersonIdAndStatus(
                personId, DomainConstants.CONSENT_ACTIVE)).thenReturn(false);
        when(telemetryRepository.findLastByMonitoredPersonId(personId))
                .thenReturn(Optional.empty());

        var result = service.getByMonitoredUserId(monitoredUserId);

        assertThat(result.id()).isEqualTo(personId);
        assertThat(result.userEmail()).isEqualTo("monitored@test.com");
    }

    @Test
    void getByMonitoredUserId_withoutProfile_throwsNotFound() {
        UUID monitoredUserId = UUID.randomUUID();
        when(repository.findByUserId(monitoredUserId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getByMonitoredUserId(monitoredUserId))
                .isInstanceOf(DomainExceptions.NotFoundException.class)
                .hasMessageContaining("not linked");
    }

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

    @Test
    void revokeConsentByMonitored_revokesActiveConsent() {
        when(repository.existsById(personId)).thenReturn(true);

        Consent existing = new Consent();
        existing.setStatus(DomainConstants.CONSENT_ACTIVE);
        when(consentRepository.findByMonitoredPersonIdAndStatus(personId,
                DomainConstants.CONSENT_ACTIVE)).thenReturn(Optional.of(existing));
        when(consentRepository.save(any())).thenReturn(existing);

        var result = service.revokeConsentByMonitored(personId);

        assertThat(existing.getStatus()).isEqualTo(DomainConstants.CONSENT_REVOKED);
        assertThat(result.status()).isEqualTo(DomainConstants.CONSENT_REVOKED);
        verify(caregiverEventPublisher).publishConsentRevoked(personId);
    }

    @Test
    void publishMonitoringEvent_started_publishesEvent() {
        UUID monitoredUserId = UUID.randomUUID();
        MonitoredPerson linked = org.mockito.Mockito.mock(MonitoredPerson.class);
        when(linked.getId()).thenReturn(personId);
        when(repository.findByUserId(monitoredUserId)).thenReturn(Optional.of(linked));

        service.publishMonitoringEvent(
                monitoredUserId, personId, DomainConstants.MONITORING_EVENT_STARTED);

        verify(caregiverEventPublisher).publishMonitoringStarted(personId);
    }

    @Test
    void publishMonitoringEvent_wrongPerson_throwsForbidden() {
        UUID monitoredUserId = UUID.randomUUID();
        MonitoredPerson linked = org.mockito.Mockito.mock(MonitoredPerson.class);
        when(linked.getId()).thenReturn(personId);
        when(repository.findByUserId(monitoredUserId)).thenReturn(Optional.of(linked));

        UUID otherPerson = UUID.randomUUID();
        assertThatThrownBy(() -> service.publishMonitoringEvent(
                monitoredUserId, otherPerson, DomainConstants.MONITORING_EVENT_STOPPED))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);
    }

    @Test
    void publishMonitoringEvent_invalidEvent_throwsBadRequest() {
        UUID monitoredUserId = UUID.randomUUID();
        MonitoredPerson linked = org.mockito.Mockito.mock(MonitoredPerson.class);
        when(linked.getId()).thenReturn(personId);
        when(repository.findByUserId(monitoredUserId)).thenReturn(Optional.of(linked));

        assertThatThrownBy(() -> service.publishMonitoringEvent(
                monitoredUserId, personId, "PAUSE"))
                .isInstanceOf(DomainExceptions.BadRequestException.class);
    }

    // ── response enrichment (T2.27) ─────────────────────────────────────────────

    @Test
    void getById_embedsLastPredictionAndActiveMonitoring() {
        // person (mock) tiene id null, así que toResponse consulta con id null:
        // usamos matchers para no acoplar el test al id generado por JPA.
        when(repository.findById(personId)).thenReturn(Optional.of(person));
        when(consentRepository.existsByMonitoredPersonIdAndStatus(any(),
                eq(DomainConstants.CONSENT_ACTIVE))).thenReturn(true);

        TelemetryWindow window = new TelemetryWindow();
        window.setMonitoredPersonId(personId);
        window.setWindowStart(Instant.now().minusSeconds(30));
        window.setWindowEnd(Instant.now().minusSeconds(28));
        window.setFallDetected(true);
        window.setConfidence(new BigDecimal("0.9200"));
        window.setModelVersion("xgb-1.2.0");
        when(telemetryRepository.findLastByMonitoredPersonId(any()))
                .thenReturn(Optional.of(window));

        var res = service.getById(caregiverId, personId);

        assertThat(res.lastPrediction()).isNotNull();
        assertThat(res.lastPrediction().fallDetected()).isTrue();
        assertThat(res.lastPrediction().confidence()).isEqualTo(0.92);
        assertThat(res.lastPrediction().modelVersion()).isEqualTo("xgb-1.2.0");
        assertThat(res.lastSeenAt()).isNotNull();
        assertThat(res.monitoringStatus()).isEqualTo(DomainConstants.MONITORING_ACTIVE);
    }

    @Test
    void getById_noWindow_inactiveMonitoringAndNoPrediction() {
        when(repository.findById(personId)).thenReturn(Optional.of(person));
        when(consentRepository.existsByMonitoredPersonIdAndStatus(any(),
                eq(DomainConstants.CONSENT_ACTIVE))).thenReturn(false);
        when(telemetryRepository.findLastByMonitoredPersonId(any()))
                .thenReturn(Optional.empty());

        var res = service.getById(caregiverId, personId);

        assertThat(res.lastPrediction()).isNull();
        assertThat(res.lastSeenAt()).isNull();
        assertThat(res.monitoringStatus()).isEqualTo(DomainConstants.MONITORING_INACTIVE);
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

    private MonitoredDtos.MonitoredRequest monitoredRequest(String email) {
        return new MonitoredDtos.MonitoredRequest(
                email,
                "Manuel Pérez",
                LocalDate.of(1948, 3, 12),
                "M",
                new BigDecimal("78.5"),
                new BigDecimal("172"),
                null);
    }
}
