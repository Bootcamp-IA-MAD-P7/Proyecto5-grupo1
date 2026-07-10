package com.sentilife.config;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Excepciones del dominio SentiLife.
 *
 * La clase base SentiLifeException centraliza el patrón constructor + factory.
 * Cada subclase solo declara su HttpStatus — cero código duplicado.
 *
 * Uso: throw NotFoundException.of("Persona no encontrada");
 */
public class DomainExceptions {

    private DomainExceptions() {}

    /** Clase base — centraliza el patrón factory `of()` */
    public abstract static class SentiLifeException extends ResponseStatusException {
        protected SentiLifeException(HttpStatus status, String message) {
            super(status, message);
        }
    }

    public static class NotFoundException extends SentiLifeException {
        private NotFoundException(String message) { super(HttpStatus.NOT_FOUND, message); }
        public static NotFoundException of(String message) { return new NotFoundException(message); }
    }

    public static class ConflictException extends SentiLifeException {
        private ConflictException(String message) { super(HttpStatus.CONFLICT, message); }
        public static ConflictException of(String message) { return new ConflictException(message); }
    }

    public static class ForbiddenException extends SentiLifeException {
        private ForbiddenException(String message) { super(HttpStatus.FORBIDDEN, message); }
        public static ForbiddenException of(String message) { return new ForbiddenException(message); }
    }

    public static class UnauthorizedException extends SentiLifeException {
        private UnauthorizedException(String message) { super(HttpStatus.UNAUTHORIZED, message); }
        public static UnauthorizedException of(String message) { return new UnauthorizedException(message); }
    }

    public static class BadRequestException extends SentiLifeException {
        private BadRequestException(String message) { super(HttpStatus.BAD_REQUEST, message); }
        public static BadRequestException of(String message) { return new BadRequestException(message); }
    }
}
