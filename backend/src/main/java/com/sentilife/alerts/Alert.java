package com.sentilife.alerts;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Alert generated when a fall is detected.
 * Created by TelemetryService when fallDetected = true.
 */
@Entity
@Table(name = "alerts")
@Getter @Setter @NoArgsConstructor
public class Alert extends BaseEntity {

    @Column(name = "monitored_person_id", nullable = false)
    private UUID monitoredPersonId;

    @Column(name = "detected_at", nullable = false)
    private Instant detectedAt = Instant.now();

    @Column(nullable = false, precision = 5, scale = 4)
    private BigDecimal confidence;

    @Column(name = "model_version", nullable = false)
    private String modelVersion;

    @Column(nullable = false)
    private String status; // PENDING | CONFIRMED | DISMISSED

    @Column(name = "reviewed_by")
    private UUID reviewedBy;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @Column(name = "telemetry_window_id")
    private UUID telemetryWindowId;
}
