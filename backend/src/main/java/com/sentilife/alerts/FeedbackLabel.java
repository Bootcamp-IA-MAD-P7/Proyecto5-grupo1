package com.sentilife.alerts;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/**
 * Caregiver feedback on an alert — TRUE_FALL or FALSE_ALARM.
 * Used to build the labelled dataset for retraining (ML-09).
 */
@Entity
@Table(name = "feedback_labels")
@Getter @Setter @NoArgsConstructor
public class FeedbackLabel extends BaseEntity {

    @Column(name = "alert_id", nullable = false)
    private UUID alertId;

    @Column(nullable = false)
    private String label; // TRUE_FALL | FALSE_ALARM

    @Column
    private String comment;

    @Column(name = "telemetry_window_ref")
    private String telemetryWindowRef;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;
}
