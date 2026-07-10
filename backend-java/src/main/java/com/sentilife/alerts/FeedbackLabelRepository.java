package com.sentilife.alerts;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface FeedbackLabelRepository extends JpaRepository<FeedbackLabel, UUID> {
}
