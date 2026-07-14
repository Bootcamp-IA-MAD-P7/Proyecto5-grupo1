package com.sentilife.config;

import com.sentilife.users.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Map;
import java.util.UUID;

/**
 * Generates and validates JWT tokens.
 *
 * Access token  — short-lived (15 min) — authenticates each request.
 * Refresh token — long-lived (7 days)  — used to get a new access token without re-login.
 *
 * Both tokens carry the user's email as subject and a "role" claim.
 * The "type" claim ("ACCESS" | "REFRESH") distinguishes them.
 */
@Service
public class JwtService {

    private final SecretKey signingKey;
    private final long accessTokenExpiration;   // seconds
    private final long refreshTokenExpiration;  // seconds
    private final long deviceTokenExpiration;   // seconds

    public JwtService(
            @Value("${sentilife.jwt.secret}") String secret,
            @Value("${sentilife.jwt.access-token-expiration}") long accessExpiration,
            @Value("${sentilife.jwt.refresh-token-expiration}") long refreshExpiration,
            @Value("${sentilife.jwt.device-token-expiration}") long deviceExpiration) {
        this.signingKey             = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiration  = accessExpiration;
        this.refreshTokenExpiration = refreshExpiration;
        this.deviceTokenExpiration  = deviceExpiration;
    }

    public String generateAccessToken(User user) {
        return buildToken(user, accessTokenExpiration, DomainConstants.TOKEN_ACCESS);
    }

    public String generateRefreshToken(User user) {
        return buildToken(user, refreshTokenExpiration, DomainConstants.TOKEN_REFRESH);
    }

    public String generateDeviceToken(UUID monitoredPersonId, String deviceId) {
        long nowMs = System.currentTimeMillis();
        return Jwts.builder()
                .subject(deviceId)
                .claims(Map.of(
                    "monitoredPersonId", monitoredPersonId.toString(),
                    "deviceId",          deviceId,
                    "type",              DomainConstants.TOKEN_DEVICE
                ))
                .issuedAt(new Date(nowMs))
                .expiration(new Date(nowMs + deviceTokenExpiration * 1000))
                .signWith(signingKey)
                .compact();
    }

    private String buildToken(User user, long expirationSeconds, String type) {
        long nowMs = System.currentTimeMillis();
        return Jwts.builder()
                .subject(user.getEmail())
                .claims(Map.of(
                    "role",   user.getRole(),
                    "userId", user.getId().toString(),
                    "type",   type
                ))
                .issuedAt(new Date(nowMs))
                .expiration(new Date(nowMs + expirationSeconds * 1000))
                .signWith(signingKey)
                .compact();
    }

    /** Extracts the email (subject) from the token. Throws if the token is invalid. */
    public String extractEmail(String token) {
        return parseClaims(token).getSubject();
    }

    public String extractType(String token) {
        return (String) parseClaims(token).get("type");
    }

    public UUID extractMonitoredPersonId(String token) {
        return UUID.fromString((String) parseClaims(token).get("monitoredPersonId"));
    }

    public String extractDeviceId(String token) {
        return (String) parseClaims(token).get("deviceId");
    }

    public boolean isValid(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
