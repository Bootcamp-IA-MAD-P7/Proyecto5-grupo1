package com.sentilife.admin;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.JwtService;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * T5.2 — RF-42: export CSV with Content-Disposition attachment header.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminControllerTest {

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired JwtService jwtService;
    @Autowired PasswordEncoder passwordEncoder;

    private String itAdminToken;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
        User admin = new User();
        admin.setEmail("admin-export@test.com");
        admin.setPasswordHash(passwordEncoder.encode("Admin1234!"));
        admin.setFullName("IT Admin");
        admin.setRole(DomainConstants.ROLE_IT_ADMIN);
        admin.setActive(true);
        userRepository.save(admin);
        itAdminToken = "Bearer " + jwtService.generateAccessToken(admin);
    }

    @Test
    void exportReturnsCsvWithContentDispositionAttachment() throws Exception {
        mockMvc.perform(get("/api/v1/admin/export").header("Authorization", itAdminToken))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, containsString("attachment")))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_DISPOSITION,
                        containsString("filename=\"sentilife-feedback-all-all.csv\"")))
                .andExpect(content().string(containsString("window_id,monitored_person_id")));
    }
}
