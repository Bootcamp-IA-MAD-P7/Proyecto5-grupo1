package com.sentilife.config;

/**
 * Domain exceptions for SentiLife.
 *
 * These are pure business exceptions — they know NOTHING about HTTP.
 * The GlobalExceptionHandler (@ControllerAdvice) is responsible for
 * mapping each exception type to the appropriate HTTP status code.
 *
 * This separation ensures:
 * 1. Domain logic doesn't depend on web layer (testable without Spring)
 * 2. Spring Security doesn't intercept our exceptions (it only catches
 *    ResponseStatusException and AuthenticationException)
 * 3. Consistent JSON error responses via a single translation point
 *
 * Usage: throw NotFoundException.of("Person not found");
 */
public class DomainExceptions {

    private DomainExceptions() {}

    /** Base class — all domain exceptions extend this. */
    public abstract static class SentiLifeException extends RuntimeException {
        protected SentiLifeException(String message) {
            super(message);
        }
    }

    /** Resource not found — maps to HTTP 404. */
    public static class NotFoundException extends SentiLifeException {
        private NotFoundException(String message) { super(message); }
        public static NotFoundException of(String message) { return new NotFoundException(message); }
    }

    /** Duplicate resource — maps to HTTP 409. */
    public static class ConflictException extends SentiLifeException {
        private ConflictException(String message) { super(message); }
        public static ConflictException of(String message) { return new ConflictException(message); }
    }

    /** Access denied (business rule) — maps to HTTP 403. */
    public static class ForbiddenException extends SentiLifeException {
        private ForbiddenException(String message) { super(message); }
        public static ForbiddenException of(String message) { return new ForbiddenException(message); }
    }

    /** Invalid credentials — maps to HTTP 401. */
    public static class UnauthorizedException extends SentiLifeException {
        private UnauthorizedException(String message) { super(message); }
        public static UnauthorizedException of(String message) { return new UnauthorizedException(message); }
    }

    /** Invalid input — maps to HTTP 400. */
    public static class BadRequestException extends SentiLifeException {
        private BadRequestException(String message) { super(message); }
        public static BadRequestException of(String message) { return new BadRequestException(message); }
    }

    /** External dependency unavailable — maps to HTTP 503. */
    public static class ServiceUnavailableException extends SentiLifeException {
        private ServiceUnavailableException(String message) { super(message); }
        public static ServiceUnavailableException of(String message) {
            return new ServiceUnavailableException(message);
        }
    }
}
