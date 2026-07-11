package com.sentilife.auth;

import com.sentilife.config.DomainExceptions;
import com.sentilife.config.JwtService;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for AuthService.
 * Uses Mockito — no Spring context needed, runs fast.
 *
 * We construct AuthService manually (not @InjectMocks) because it
 * has a @Value int parameter that Mockito can't inject.
 *
 * Lenient strictness: setUp() prepares common stubs (JWT generation)
 * that not every test path reaches — that's intentional, not a bug.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AuthServiceTest {

    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;

    AuthService authService;

    private User mockUser;

    @BeforeEach
    void setUp() {
        // Manual construction: 4th arg is accessTokenExpiration (seconds)
        authService = new AuthService(userRepository, passwordEncoder, jwtService, 900);

        mockUser = new User();
        mockUser.setEmail("ana@test.com");
        mockUser.setPasswordHash("hashed");
        mockUser.setFullName("Ana García");
        mockUser.setRole("CAREGIVER");
        mockUser.setLocale("es");
        mockUser.setActive(true);

        when(jwtService.generateAccessToken(any())).thenReturn("access-token");
        when(jwtService.generateRefreshToken(any())).thenReturn("refresh-token");
    }

    // ── register ──────────────────────────────────────────────────────────────

    @Test
    void register_success() {
        when(userRepository.existsByEmail("ana@test.com")).thenReturn(false);
        when(passwordEncoder.encode("Password1!")).thenReturn("hashed");
        when(userRepository.save(any())).thenReturn(mockUser);

        var request = new AuthDtos.RegisterRequest(
                "ana@test.com", "Password1!", "Ana García", "CAREGIVER", "es");

        var response = authService.register(request);

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.user().role()).isEqualTo("CAREGIVER");
        verify(userRepository).save(any());
    }

    @Test
    void register_duplicateEmail_throwsConflict() {
        when(userRepository.existsByEmail("ana@test.com")).thenReturn(true);

        var request = new AuthDtos.RegisterRequest(
                "ana@test.com", "Password1!", "Ana García", "CAREGIVER", "es");

        assertThatThrownBy(() -> authService.register(request))
                .isInstanceOf(DomainExceptions.ConflictException.class);
    }

    @Test
    void register_shortPassword_throwsBadRequest() {
        when(userRepository.existsByEmail(any())).thenReturn(false);

        var request = new AuthDtos.RegisterRequest(
                "ana@test.com", "short", "Ana García", "CAREGIVER", "es");

        assertThatThrownBy(() -> authService.register(request))
                .isInstanceOf(DomainExceptions.BadRequestException.class);
    }

    // ── login ─────────────────────────────────────────────────────────────────

    @Test
    void login_success() {
        when(userRepository.findByEmail("ana@test.com")).thenReturn(Optional.of(mockUser));
        when(passwordEncoder.matches("Password1!", "hashed")).thenReturn(true);

        var response = authService.login(new AuthDtos.LoginRequest("ana@test.com", "Password1!"));

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.user().email()).isEqualTo("ana@test.com");
    }

    @Test
    void login_wrongPassword_throwsUnauthorized() {
        when(userRepository.findByEmail("ana@test.com")).thenReturn(Optional.of(mockUser));
        when(passwordEncoder.matches(anyString(), anyString())).thenReturn(false);

        assertThatThrownBy(() -> authService.login(
                new AuthDtos.LoginRequest("ana@test.com", "wrong")))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);
    }

    @Test
    void login_unknownEmail_throwsUnauthorized() {
        when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(
                new AuthDtos.LoginRequest("unknown@test.com", "Password1!")))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);
    }

    @Test
    void login_inactiveUser_throwsForbidden() {
        mockUser.setActive(false);
        when(userRepository.findByEmail("ana@test.com")).thenReturn(Optional.of(mockUser));
        when(passwordEncoder.matches(anyString(), anyString())).thenReturn(true);

        assertThatThrownBy(() -> authService.login(
                new AuthDtos.LoginRequest("ana@test.com", "Password1!")))
                .isInstanceOf(DomainExceptions.ForbiddenException.class);
    }

    // ── refresh ───────────────────────────────────────────────────────────────

    @Test
    void refresh_invalidToken_throwsUnauthorized() {
        when(jwtService.isValid("bad-token")).thenReturn(false);

        assertThatThrownBy(() -> authService.refresh(
                new AuthDtos.RefreshRequest("bad-token")))
                .isInstanceOf(DomainExceptions.UnauthorizedException.class);
    }
}
