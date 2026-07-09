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
 * Configuración de seguridad.
 *
 * - Stateless: no hay sesión HTTP, cada request se autentica con JWT.
 * - JwtAuthFilter se ejecuta antes del filtro de autenticación de Spring.
 * - Endpoints públicos: actuator/health, auth/*, devices/pair, telemetría (temp).
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
                // Actuator — público
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/actuator/prometheus").permitAll()
                // Auth — público
                .requestMatchers("/api/v1/auth/**").permitAll()
                // Vinculación de dispositivo — público (usa pairingCode)
                .requestMatchers("/api/v1/devices/pair").permitAll()
                // Telemetría — temporal hasta completar JWT en dispositivos (Fase 2)
                .requestMatchers("/api/v1/telemetry/**").permitAll()
                // Todo lo demás requiere JWT válido
                .anyRequest().authenticated()
            )
            // Añadir el filtro JWT antes del filtro de autenticación de Spring
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * BCrypt con coste 12 — estándar para contraseñas en producción.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
