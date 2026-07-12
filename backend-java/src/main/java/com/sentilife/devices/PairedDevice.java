package com.sentilife.devices;

import com.sentilife.config.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Entity
@Table(name = "paired_devices")
@Getter @Setter @NoArgsConstructor
public class PairedDevice extends BaseEntity {

    @Column(name = "monitored_person_id", nullable = false)
    private UUID monitoredPersonId;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(nullable = false)
    private String platform;

    @Column(name = "device_token_hash")
    private String deviceTokenHash;

    @Column(nullable = false)
    private Boolean active = true;
}
