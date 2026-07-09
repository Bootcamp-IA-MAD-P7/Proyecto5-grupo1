package com.sentilife.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Configuración de seguridad base.
 * Los endpoints de auth y actuator son públicos.
 * El resto requiere JWT (se completará en Fase 2 con JwtAuthFilter).
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // Actuator health — público
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                // Prometheus — solo red interna en producción; permitAll en desarrollo
                .requestMatchers("/actuator/prometheus").permitAll()
                // Auth endpoints — públicos
                .requestMatchers("/api/v1/auth/**").permitAll()
                // Todo lo demás requiere autenticación
                .anyRequest().authenticated()
            );

        return http.build();
    }
}
