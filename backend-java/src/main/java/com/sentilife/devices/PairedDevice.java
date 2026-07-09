package com.sentilife.devices;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "paired_devices")
@Getter @Setter @NoArgsConstructor
public class PairedDevice {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "monitored_person_id", nullable = false)
    private UUID monitoredPersonId;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(nullable = false)
    private String platform;  // ANDROID | IOS

    @Column(name = "device_token_hash")
    private String deviceTokenHash;

    @Column(name = "paired_at", nullable = false, updatable = false)
    private Instant pairedAt = Instant.now();

    @Column(nullable = false)
    private Boolean active = true;
}
