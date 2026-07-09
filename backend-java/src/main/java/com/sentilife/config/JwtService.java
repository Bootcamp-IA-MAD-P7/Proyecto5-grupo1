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

/**
 * Genera y valida tokens JWT.
 *
 * Access token  — corto (15 min) — para autenticar cada request.
 * Refresh token — largo (7 días) — para obtener un nuevo access token sin relogin.
 *
 * Ambos llevan como subject el email del usuario y un claim "role".
 * El tipo ("ACCESS" | "REFRESH") va en el claim "type" para distinguirlos.
 */
@Service
public class JwtService {

    private final SecretKey signingKey;
    private final long accessTokenExpiration;   // segundos
    private final long refreshTokenExpiration;  // segundos

    public JwtService(
            @Value("${sentilife.jwt.secret}") String secret,
            @Value("${sentilife.jwt.access-token-expiration}") long accessExpiration,
            @Value("${sentilife.jwt.refresh-token-expiration}") long refreshExpiration) {
        this.signingKey           = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiration  = accessExpiration;
        this.refreshTokenExpiration = refreshExpiration;
    }

    public String generateAccessToken(User user) {
        return buildToken(user, accessTokenExpiration, "ACCESS");
    }

    public String generateRefreshToken(User user) {
        return buildToken(user, refreshTokenExpiration, "REFRESH");
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

    /** Extrae el email (subject) del token. Lanza excepción si el token es inválido. */
    public String extractEmail(String token) {
        return parseClaims(token).getSubject();
    }

    public String extractType(String token) {
        return (String) parseClaims(token).get("type");
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
