package com.sentilife.config;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.Map;

/**
 * Global exception handler — catches all DomainExceptions and returns
 * a consistent JSON error response.
 *
 * This prevents Spring Security from intercepting our 401/403 responses
 * and replacing them with empty bodies.
 *
 * Response format (spec §6 error contract):
 * {
 *   "timestamp": "2026-07-12T16:00:00Z",
 *   "status": 401,
 *   "error": "UNAUTHORIZED",
 *   "message": "Credenciales inválidas"
 * }
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String, Object>> handleAccessDenied(AccessDeniedException ex) {
        return buildResponse(403, "FORBIDDEN", "Access denied");
    }

    @ExceptionHandler(DomainExceptions.NotFoundException.class)
    public ResponseEntity<Map<String, Object>> handleNotFound(DomainExceptions.NotFoundException ex) {
        return buildResponse(404, "NOT_FOUND", ex.getMessage());
    }

    @ExceptionHandler(DomainExceptions.ConflictException.class)
    public ResponseEntity<Map<String, Object>> handleConflict(DomainExceptions.ConflictException ex) {
        return buildResponse(409, "CONFLICT", ex.getMessage());
    }

    @ExceptionHandler(DomainExceptions.ForbiddenException.class)
    public ResponseEntity<Map<String, Object>> handleForbidden(DomainExceptions.ForbiddenException ex) {
        return buildResponse(403, "FORBIDDEN", ex.getMessage());
    }

    @ExceptionHandler(DomainExceptions.UnauthorizedException.class)
    public ResponseEntity<Map<String, Object>> handleUnauthorized(DomainExceptions.UnauthorizedException ex) {
        return buildResponse(401, "UNAUTHORIZED", ex.getMessage());
    }

    @ExceptionHandler(DomainExceptions.BadRequestException.class)
    public ResponseEntity<Map<String, Object>> handleBadRequest(DomainExceptions.BadRequestException ex) {
        return buildResponse(400, "BAD_REQUEST", ex.getMessage());
    }

    @ExceptionHandler(DomainExceptions.ServiceUnavailableException.class)
    public ResponseEntity<Map<String, Object>> handleServiceUnavailable(
            DomainExceptions.ServiceUnavailableException ex) {
        return buildResponse(503, "SERVICE_UNAVAILABLE", ex.getMessage());
    }

    private ResponseEntity<Map<String, Object>> buildResponse(int status, String error, String message) {
        return ResponseEntity.status(status).body(Map.of(
                "timestamp", Instant.now().toString(),
                "status", status,
                "error", error,
                "message", message != null ? message : "Unknown error"
        ));
    }
}
