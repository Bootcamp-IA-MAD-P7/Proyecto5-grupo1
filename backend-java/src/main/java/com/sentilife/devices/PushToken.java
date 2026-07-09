package com.sentilife.devices;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "push_tokens")
@Getter @Setter @NoArgsConstructor
public class PushToken {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "fcm_token", nullable = false)
    private String fcmToken;

    @Column(nullable = false)
    private String platform;  // ANDROID | IOS

    @Column(nullable = false)
    private String locale = "es";

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();
}
