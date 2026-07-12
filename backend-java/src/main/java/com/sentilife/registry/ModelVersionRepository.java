package com.sentilife.registry;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ModelVersionRepository extends JpaRepository<ModelVersion, UUID> {

    Optional<ModelVersion> findByVersion(String version);

    Optional<ModelVersion> findByStatus(String status);

    List<ModelVersion> findAllByOrderByCreatedAtDesc();
}
