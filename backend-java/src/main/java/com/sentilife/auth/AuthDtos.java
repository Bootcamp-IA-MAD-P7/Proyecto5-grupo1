package com.sentilife.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import java.util.UUID;

/**
 * Authentication DTOs — exact contracts from spec §6.1.
 */
public class AuthDtos {

    // ── POST /auth/register ──────────────────────────────────────────────────

    public record RegisterRequest(
        @Email @NotBlank String email,
        @NotBlank String password,  // min 8 chars, validated in service
        @NotBlank String fullName,
        @Pattern(regexp = "MONITORED|CAREGIVER") String role,  // IT_ADMIN is not publicly registered
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

    // ── Shared responses ─────────────────────────────────────────────────────

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
        int expiresIn,      // seconds until access token expiration
        UserInfo user
    ) {}
}
