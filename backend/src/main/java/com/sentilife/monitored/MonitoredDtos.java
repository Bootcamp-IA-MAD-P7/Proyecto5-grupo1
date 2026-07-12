package com.sentilife.monitored;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.UUID;

/**
 * DTOs de personas monitorizadas — contratos exactos de spec §6.2.
 */
public class MonitoredDtos {

    // ── POST / y PUT /{id} ────────────────────────────────────────────────────

    public record MonitoredRequest(
        @NotBlank String fullName,
        @NotNull @Past LocalDate birthDate,
        @NotNull String sex,                 // M | F | OTHER
        BigDecimal weightKg,
        BigDecimal heightCm,
        String emergencyContact
    ) {}

    // ── Response ──────────────────────────────────────────────────────────────

    public record MonitoredResponse(
        UUID id,
        String fullName,
        LocalDate birthDate,
        int age,                             // calculado desde birthDate
        String sex,
        BigDecimal weightKg,
        BigDecimal heightCm,
        String emergencyContact,
        String consentStatus,                // PENDING | ACTIVE | REVOKED
        String monitoringStatus,             // ACTIVE | INACTIVE
        String pairingCode,
        Instant createdAt
    ) {
        /** Construye la respuesta desde la entidad calculando la edad. */
        public static MonitoredResponse from(MonitoredPerson p, String consentStatus,
                                             String monitoringStatus) {
            int age = Period.between(p.getBirthDate(), LocalDate.now()).getYears();
            return new MonitoredResponse(
                p.getId(), p.getFullName(), p.getBirthDate(), age,
                p.getSex(), p.getWeightKg(), p.getHeightCm(),
                p.getEmergencyContact(), consentStatus, monitoringStatus,
                p.getPairingCode(), p.getCreatedAt()
            );
        }
    }

    // ── Consentimiento ────────────────────────────────────────────────────────

    public record ConsentRequest(
        @NotBlank String policyVersion,      // ej. "1.0-es"
        @NotBlank String acceptedBy          // "MONITORED" | "CAREGIVER"
    ) {}

    public record ConsentResponse(
        UUID id,
        UUID monitoredPersonId,
        String policyVersion,
        String status,
        Instant acceptedAt,
        Instant revokedAt
    ) {}
}
