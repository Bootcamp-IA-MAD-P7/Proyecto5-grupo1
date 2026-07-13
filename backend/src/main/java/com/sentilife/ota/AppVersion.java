package com.sentilife.ota;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "app_versions")
@Getter
@Setter
@NoArgsConstructor
public class AppVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "version_code", nullable = false, unique = true)
    private Integer versionCode;

    @Column(name = "version_name", nullable = false, length = 50)
    private String versionName;

    @Column(name = "apk_url", nullable = false, columnDefinition = "TEXT")
    private String apkUrl;

    @Column(name = "release_notes", columnDefinition = "TEXT")
    private String releaseNotes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
