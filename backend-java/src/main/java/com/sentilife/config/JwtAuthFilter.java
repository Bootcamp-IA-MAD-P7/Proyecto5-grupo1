package com.sentilife.config;

import com.sentilife.users.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * JWT filter — runs once per request.
 *
 * Flow:
 *   1. Read Authorization: Bearer <token> header
 *   2. Validate the token with JwtService
 *   3. Load the user from the database
 *   4. Set the authentication in the SecurityContext
 *      → Spring Security knows who the user is for the rest of the request
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    public JwtAuthFilter(JwtService jwtService, UserRepository userRepository) {
        this.jwtService     = jwtService;
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {

        final String authHeader = request.getHeader("Authorization");

        // No header or does not start with "Bearer " — pass through unauthenticated
        if (authHeader == null || !authHeader.startsWith(DomainConstants.BEARER_PREFIX)) {
            filterChain.doFilter(request, response);
            return;
        }

        final String token = authHeader.substring(DomainConstants.BEARER_PREFIX.length());

        if (!jwtService.isValid(token)) {
            filterChain.doFilter(request, response);
            return;
        }

        // Only access tokens authenticate regular requests
        if (!DomainConstants.TOKEN_ACCESS.equals(jwtService.extractType(token))) {
            filterChain.doFilter(request, response);
            return;
        }

        final String email = jwtService.extractEmail(token);

        // Do not overwrite an existing authentication in the context
        if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            userRepository.findByEmail(email).ifPresent(user -> {
                var authToken = new UsernamePasswordAuthenticationToken(
                        user, null, user.getAuthorities());
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(authToken);
            });
        }

        filterChain.doFilter(request, response);
    }
}
