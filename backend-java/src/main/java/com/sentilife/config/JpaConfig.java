package com.sentilife.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Enables automatic JPA auditing.
 * Required for @CreatedDate in BaseEntity to work.
 */
@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
