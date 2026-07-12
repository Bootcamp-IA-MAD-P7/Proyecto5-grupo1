package com.sentilife.registry;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.Map;

/**
 * Registered model version in the ML registry.
 *
 * Statuses:
 * - CANDIDATE: newly trained, awaiting promotion
 * - ACTIVE: currently serving predictions (only one at a time)
 * - RETIRED: replaced by a newer model
 */
@Entity
@Table(name = "model_registry")
@Getter @Setter @NoArgsConstructor
public class ModelVersion extends BaseEntity {

    @Column(nullable = false, unique = true)
    private String version;

    @Column(nullable = false)
    private String algorithm;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "metrics_json", nullable = false)
    private Map<String, Object> metricsJson;

    @Column(name = "artifact_uri", nullable = false)
    private String artifactUri;

    @Column(nullable = false)
    private String status = "CANDIDATE";
}
