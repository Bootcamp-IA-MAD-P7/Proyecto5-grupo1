package com.sentilife.devices;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PushTokenRepository extends JpaRepository<PushToken, UUID> {

    Optional<PushToken> findByUserIdAndDeviceId(UUID userId, String deviceId);

    List<PushToken> findByUserId(UUID userId);
}
