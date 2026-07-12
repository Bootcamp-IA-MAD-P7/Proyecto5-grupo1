package com.sentilife.consent;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "consents")
@Getter @Setter @NoArgsConstructor
public class Consent extends BaseEntity {

    @Column(name = "monitored_person_id", nullable = false)
    private UUID monitoredPersonId;

    @Column(name = "policy_version", nullable = false)
    private String policyVersion;

    @Column(nullable = false)
    private String status;

    @Column(name = "accepted_at", nullable = false, updatable = false)
    private Instant acceptedAt = Instant.now();

    @Column(name = "revoked_at")
    private Instant revokedAt;
}
