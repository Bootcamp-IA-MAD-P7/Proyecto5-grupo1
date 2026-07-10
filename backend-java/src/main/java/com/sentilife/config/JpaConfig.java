package com.sentilife.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Activa la auditoría automática de JPA.
 * Necesario para que @CreatedDate en BaseEntity funcione.
 */
@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
