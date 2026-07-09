package com.sentilife.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import java.util.UUID;

/**
 * DTOs de autenticación — contratos exactos de spec §6.1.
 */
public class AuthDtos {

    // ── POST /auth/register ──────────────────────────────────────────────────

    public record RegisterRequest(
        @Email @NotBlank String email,
        @NotBlank String password,  // mín 8 chars, validación en servicio
        @NotBlank String fullName,
        @Pattern(regexp = "MONITORED|CAREGIVER") String role,  // IT_ADMIN no se registra públicamente
        String locale
    ) {}

    // ── POST /auth/login ─────────────────────────────────────────────────────

    public record LoginRequest(
        @Email @NotBlank String email,
        @NotBlank String password
    ) {}

    // ── POST /auth/refresh ───────────────────────────────────────────────────

    public record RefreshRequest(
        @NotBlank String refreshToken
    ) {}

    // ── Respuestas comunes ───────────────────────────────────────────────────

    public record UserInfo(
        UUID id,
        String email,
        String fullName,
        String role,
        String locale
    ) {}

    public record AuthResponse(
        String accessToken,
        String refreshToken,
        int expiresIn,      // segundos hasta expiración del access token
        UserInfo user
    ) {}
}
