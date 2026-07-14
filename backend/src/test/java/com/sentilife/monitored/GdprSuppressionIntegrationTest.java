package com.sentilife.monitored;

import com.sentilife.alerts.Alert;
import com.sentilife.alerts.AlertRepository;
import com.sentilife.alerts.FeedbackLabel;
import com.sentilife.alerts.FeedbackLabelRepository;
import com.sentilife.config.DomainConstants;
import com.sentilife.config.JwtService;
import com.sentilife.consent.Consent;
import com.sentilife.consent.ConsentRepository;
import com.sentilife.devices.PairedDevice;
import com.sentilife.devices.PairedDeviceRepository;
import com.sentilife.telemetry.TelemetryWindow;
import com.sentilife.telemetry.TelemetryWindowRepository;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * T3.6 / RF-08 — GDPR full suppression demonstrated against a real database (H2).
 *
 * Seeds persona + consent + device + telemetry + alert + feedback, then
 * DELETE /api/v1/monitored-persons/{id} and asserts zero rows remain.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class GdprSuppressionIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired MonitoredPersonRepository monitoredPersonRepository;
    @Autowired ConsentRepository consentRepository;
    @Autowired PairedDeviceRepository pairedDeviceRepository;
    @Autowired TelemetryWindowRepository telemetryWindowRepository;
    @Autowired AlertRepository alertRepository;
    @Autowired FeedbackLabelRepository feedbackLabelRepository;
    @Autowired JwtService jwtService;
    @Autowired PasswordEncoder passwordEncoder;

    private User caregiver;
    private User monitoredUser;
    private String caregiverToken;

    @BeforeEach
    void setUp() {
        feedbackLabelRepository.deleteAll();
        alertRepository.deleteAll();
        telemetryWindowRepository.deleteAll();
        pairedDeviceRepository.deleteAll();
        consentRepository.deleteAll();
        monitoredPersonRepository.deleteAll();
        userRepository.deleteAll();

        caregiver = saveUser("cg-gdpr@test.com", DomainConstants.ROLE_CAREGIVER);
        monitoredUser = saveUser("mon-gdpr@test.com", DomainConstants.ROLE_MONITORED);
        caregiverToken = DomainConstants.BEARER_PREFIX + jwtService.generateAccessToken(caregiver);
    }

    @Test
    void deleteMonitoredPerson_wipesAllRelatedData() throws Exception {
        MonitoredPerson person = linkedPerson(caregiver, monitoredUser);
        UUID personId = person.getId();

        Consent consent = new Consent();
        consent.setMonitoredPersonId(personId);
        consent.setPolicyVersion("1.0-es");
        consent.setStatus(DomainConstants.CONSENT_ACTIVE);
        consentRepository.save(consent);

        PairedDevice device = new PairedDevice();
        device.setMonitoredPersonId(personId);
        device.setDeviceId("android-gdpr-1");
        device.setPlatform(DomainConstants.PLATFORM_ANDROID);
        device.setActive(true);
        pairedDeviceRepository.save(device);

        Instant now = Instant.now();
        TelemetryWindow window = new TelemetryWindow();
        window.setMonitoredPersonId(personId);
        window.setDeviceId(device.getDeviceId());
        window.setWindowStart(now.minusSeconds(3));
        window.setWindowEnd(now);
        window.setSampleRateHz(50);
        window.setSamplesJson(Map.of("accX", new double[] {0.1}));
        window.setFallDetected(true);
        window.setConfidence(new BigDecimal("0.9100"));
        window.setModelVersion("baseline-v1");
        window = telemetryWindowRepository.save(window);

        Alert alert = new Alert();
        alert.setMonitoredPersonId(personId);
        alert.setDetectedAt(now);
        alert.setConfidence(new BigDecimal("0.9100"));
        alert.setModelVersion("baseline-v1");
        alert.setStatus(DomainConstants.ALERT_CONFIRMED);
        alert.setTelemetryWindowId(window.getId());
        alert = alertRepository.save(alert);

        FeedbackLabel feedback = new FeedbackLabel();
        feedback.setAlertId(alert.getId());
        feedback.setLabel("TRUE_FALL");
        feedback.setComment("Confirmed in GDPR integration test");
        feedback.setCreatedBy(caregiver.getId());
        feedback.setTelemetryWindowRef(window.getId().toString());
        feedbackLabelRepository.save(feedback);

        assertThat(monitoredPersonRepository.findById(personId)).isPresent();
        assertThat(consentRepository.countByMonitoredPersonId(personId)).isEqualTo(1);
        assertThat(pairedDeviceRepository.countByMonitoredPersonId(personId)).isEqualTo(1);
        assertThat(telemetryWindowRepository.countByMonitoredPersonId(personId)).isEqualTo(1);
        assertThat(alertRepository.countByMonitoredPersonId(personId)).isEqualTo(1);
        assertThat(feedbackLabelRepository.findByAlertId(alert.getId())).isPresent();

        mockMvc.perform(delete("/api/v1/monitored-persons/{id}", personId)
                        .header("Authorization", caregiverToken))
                .andExpect(status().isNoContent());

        assertThat(monitoredPersonRepository.findById(personId)).isEmpty();
        assertThat(consentRepository.countByMonitoredPersonId(personId)).isZero();
        assertThat(pairedDeviceRepository.countByMonitoredPersonId(personId)).isZero();
        assertThat(telemetryWindowRepository.countByMonitoredPersonId(personId)).isZero();
        assertThat(alertRepository.countByMonitoredPersonId(personId)).isZero();
        assertThat(feedbackLabelRepository.findByAlertId(alert.getId())).isEmpty();

        // User accounts survive — only monitored-person data is erased (RF-08 scope).
        assertThat(userRepository.findById(monitoredUser.getId())).isPresent();
        assertThat(userRepository.findById(caregiver.getId())).isPresent();
    }

    private User saveUser(String email, String role) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode("TestPass1!"));
        user.setFullName(role);
        user.setRole(role);
        user.setLocale("es");
        user.setActive(true);
        return userRepository.save(user);
    }

    private MonitoredPerson linkedPerson(User caregiverUser, User monitoredAccount) {
        MonitoredPerson person = new MonitoredPerson();
        person.setCaregiverId(caregiverUser.getId());
        person.setUserId(monitoredAccount.getId());
        person.setFullName("GDPR Demo");
        person.setBirthDate(LocalDate.of(1945, 5, 10));
        person.setSex("F");
        person.setPairingCode("SL-GDPR1");
        return monitoredPersonRepository.save(person);
    }
}
