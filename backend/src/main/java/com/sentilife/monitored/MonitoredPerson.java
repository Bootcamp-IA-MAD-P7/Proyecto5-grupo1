package com.sentilife.monitored;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "monitored_persons")
@Getter @Setter @NoArgsConstructor
public class MonitoredPerson extends BaseEntity {

    @Column(name = "caregiver_id", nullable = false)
    private UUID caregiverId;

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "birth_date", nullable = false)
    private LocalDate birthDate;

    @Column(nullable = false)
    private String sex;

    @Column(name = "weight_kg", precision = 5, scale = 2)
    private BigDecimal weightKg;

    @Column(name = "height_cm", precision = 5, scale = 2)
    private BigDecimal heightCm;

    @Column(name = "emergency_contact")
    private String emergencyContact;

    @Column(name = "pairing_code", unique = true)
    private String pairingCode;
}
