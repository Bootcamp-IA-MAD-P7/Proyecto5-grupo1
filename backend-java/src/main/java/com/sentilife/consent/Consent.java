package com.sentilife.consent;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Consentimiento GDPR de una persona monitorizada.
 * Solo puede haber uno ACTIVE por persona a la vez (índice único en BD).
 */
@Entity
@Table(name = "consents")
@Getter @Setter @NoArgsConstructor
public class Consent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "monitored_person_id", nullable = false)
    private UUID monitoredPersonId;

    @Column(name = "policy_version", nullable = false)
    private String policyVersion;

    @Column(nullable = false)
    private String status;  // ACTIVE | REVOKED

    @Column(name = "accepted_at", nullable = false, updatable = false)
    private Instant acceptedAt = Instant.now();

    @Column(name = "revoked_at")
    private Instant revokedAt;
}
