package com.sentilife.config;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Excepciones del dominio SentiLife.
 *
 * Centralizan los códigos HTTP y mensajes — evita repetir
 * new ResponseStatusException(HttpStatus.X, "mensaje") en cada servicio.
 *
 * Uso: throw NotFoundException.of("Persona no encontrada");
 */
public class DomainExceptions {

    private DomainExceptions() {}

    public static class NotFoundException extends ResponseStatusException {
        public NotFoundException(String message) {
            super(HttpStatus.NOT_FOUND, message);
        }
        public static NotFoundException of(String message) {
            return new NotFoundException(message);
        }
    }

    public static class ConflictException extends ResponseStatusException {
        public ConflictException(String message) {
            super(HttpStatus.CONFLICT, message);
        }
        public static ConflictException of(String message) {
            return new ConflictException(message);
        }
    }

    public static class ForbiddenException extends ResponseStatusException {
        public ForbiddenException(String message) {
            super(HttpStatus.FORBIDDEN, message);
        }
        public static ForbiddenException of(String message) {
            return new ForbiddenException(message);
        }
    }

    public static class UnauthorizedException extends ResponseStatusException {
        public UnauthorizedException(String message) {
            super(HttpStatus.UNAUTHORIZED, message);
        }
        public static UnauthorizedException of(String message) {
            return new UnauthorizedException(message);
        }
    }

    public static class BadRequestException extends ResponseStatusException {
        public BadRequestException(String message) {
            super(HttpStatus.BAD_REQUEST, message);
        }
        public static BadRequestException of(String message) {
            return new BadRequestException(message);
        }
    }
}
