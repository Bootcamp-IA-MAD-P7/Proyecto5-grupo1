package com.sentilife.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Security configuration.
 *
 * - Stateless: no HTTP session, every request is authenticated with JWT.
 * - JwtAuthFilter runs before Spring's authentication filter.
 * - Public endpoints: actuator/health, auth/*, devices/pair, telemetry (temporary).
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // Actuator — public
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/actuator/prometheus").permitAll()
                // Auth — public
                .requestMatchers("/api/v1/auth/**").permitAll()
                // Device pairing — public (uses pairingCode)
                .requestMatchers("/api/v1/devices/pair").permitAll()
                // OTA Android — public (Flutter + CI)
                .requestMatchers("/app/**").permitAll()
                // Telemetry — open until device JWT is implemented (Phase 2)
                .requestMatchers("/api/v1/telemetry/**").permitAll()
                // Everything else requires a valid JWT
                .anyRequest().authenticated()
            )
            // Add JWT filter before Spring's authentication filter
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * BCrypt with cost 12 — production standard for password hashing.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
