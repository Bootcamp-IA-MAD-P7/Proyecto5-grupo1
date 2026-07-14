package com.sentilife.config;

import com.sentilife.monitored.MonitoredPerson;
import com.sentilife.monitored.MonitoredPersonRepository;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * T3.4 — MockMvc integration tests for JWT role enforcement (spec §6, RF-02).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApiSecurityIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired MonitoredPersonRepository monitoredPersonRepository;
    @Autowired JwtService jwtService;
    @Autowired PasswordEncoder passwordEncoder;

    private User caregiver;
    private User monitored;
    private User itAdmin;
    private String caregiverToken;
    private String monitoredToken;
    private String itAdminToken;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
        monitoredPersonRepository.deleteAll();

        caregiver = saveUser("caregiver-sec@test.com", DomainConstants.ROLE_CAREGIVER);
        monitored = saveUser("monitored-sec@test.com", DomainConstants.ROLE_MONITORED);
        itAdmin = saveUser("admin-sec@test.com", DomainConstants.ROLE_IT_ADMIN);

        caregiverToken = bearer(jwtService.generateAccessToken(caregiver));
        monitoredToken = bearer(jwtService.generateAccessToken(monitored));
        itAdminToken = bearer(jwtService.generateAccessToken(itAdmin));
    }

    @Test
    void unauthenticatedAdminRequestReturns401Json() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }

    @Test
    void caregiverCannotAccessAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users").header("Authorization", caregiverToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/admin/export").header("Authorization", caregiverToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/admin/retrain/status").header("Authorization", caregiverToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/admin/models/active").header("Authorization", caregiverToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void itAdminCanAccessAdminUsers() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users").header("Authorization", itAdminToken))
                .andExpect(status().isOk());
    }

    @Test
    void monitoredCannotListAlerts() throws Exception {
        mockMvc.perform(get("/api/v1/alerts").header("Authorization", monitoredToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void monitoredCannotCreateMonitoredPerson() throws Exception {
        mockMvc.perform(post("/api/v1/monitored-persons")
                        .header("Authorization", monitoredToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "monitoredUserEmail": "other@test.com",
                                  "fullName": "Test",
                                  "birthDate": "1940-01-01",
                                  "sex": "F"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void caregiverCannotAccessMonitoredProfileMe() throws Exception {
        mockMvc.perform(get("/api/v1/monitored-persons/me").header("Authorization", caregiverToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void consentWithoutPairingReturns403Json() throws Exception {
        MonitoredPerson person = linkedPerson(caregiver, monitored);

        mockMvc.perform(post("/api/v1/monitored-persons/{id}/consent", person.getId())
                        .header("Authorization", monitoredToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"policyVersion":"1.0-es","acceptedBy":"MONITORED"}
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"))
                .andExpect(jsonPath("$.message").value("Device not paired for this person"));
    }

    @Test
    void caregiverCanListOwnAlerts() throws Exception {
        mockMvc.perform(get("/api/v1/alerts").header("Authorization", caregiverToken))
                .andExpect(status().isOk());
    }

    @Test
    void alertPatchRequiresCaregiverRole() throws Exception {
        UUID alertId = UUID.randomUUID();
        mockMvc.perform(patch("/api/v1/alerts/{id}", alertId)
                        .header("Authorization", monitoredToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"status":"CONFIRMED","comment":"test"}
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
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

    private MonitoredPerson linkedPerson(User caregiverUser, User monitoredUser) {
        MonitoredPerson person = new MonitoredPerson();
        person.setCaregiverId(caregiverUser.getId());
        person.setUserId(monitoredUser.getId());
        person.setFullName("Demo Person");
        person.setBirthDate(LocalDate.of(1940, 1, 1));
        person.setSex("F");
        person.setPairingCode("SL-SEC01");
        return monitoredPersonRepository.save(person);
    }

    private static String bearer(String token) {
        return DomainConstants.BEARER_PREFIX + token;
    }
}
