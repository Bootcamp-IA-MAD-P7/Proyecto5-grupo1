package com.sentilife.telemetry;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Ventana de sensores enviada por el móvil.
 * Fallback ADR-03: se persiste en PostgreSQL hasta integrar InfluxDB.
 */
@Entity
@Table(name = "telemetry_windows")
@Getter @Setter @NoArgsConstructor
public class TelemetryWindow extends BaseEntity {

    @Column(name = "monitored_person_id", nullable = false)
    private UUID monitoredPersonId;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "window_start", nullable = false)
    private Instant windowStart;

    @Column(name = "window_end", nullable = false)
    private Instant windowEnd;

    @Column(name = "sample_rate_hz", nullable = false)
    private Integer sampleRateHz;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "samples_json", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> samplesJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "context_json", columnDefinition = "jsonb")
    private Map<String, Object> contextJson;

    @Column(name = "fall_detected")
    private Boolean fallDetected;

    @Column(name = "confidence", precision = 5, scale = 4)
    private BigDecimal confidence;

    @Column(name = "model_version")
    private String modelVersion;

    @Column(name = "latency_ms")
    private Integer latencyMs;
}
