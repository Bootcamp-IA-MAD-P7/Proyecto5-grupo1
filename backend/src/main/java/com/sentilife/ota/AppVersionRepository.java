package com.sentilife.ota;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AppVersionRepository extends JpaRepository<AppVersion, Integer> {

    Optional<AppVersion> findTopByOrderByVersionCodeDesc();
}
