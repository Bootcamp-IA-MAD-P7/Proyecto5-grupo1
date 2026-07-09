package com.sentilife.auth;

import com.sentilife.config.JwtService;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Lógica de negocio de autenticación.
 *
 * register: crea un usuario, hashea la contraseña con BCrypt, devuelve tokens.
 * login:    valida email/password, devuelve tokens.
 * refresh:  valida el refresh token y genera un nuevo par de tokens.
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final int accessTokenExpiration;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            @Value("${sentilife.jwt.access-token-expiration}") int accessExpiration) {
        this.userRepository      = userRepository;
        this.passwordEncoder     = passwordEncoder;
        this.jwtService          = jwtService;
        this.accessTokenExpiration = accessExpiration;
    }

    @Transactional
    public AuthDtos.AuthResponse register(AuthDtos.RegisterRequest request) {
        // 1. Validar que el email no exista
        if (userRepository.existsByEmail(request.email())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email ya registrado");
        }

        // 2. Validar contraseña (mínimo 8 caracteres)
        if (request.password().length() < 8) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La contraseña debe tener al menos 8 caracteres");
        }

        // 3. Crear el usuario
        User user = new User();
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setFullName(request.fullName());
        user.setRole(request.role());
        user.setLocale(request.locale() != null ? request.locale() : "es");
        user.setActive(true);
        user = userRepository.save(user);

        return buildAuthResponse(user);
    }

    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.UNAUTHORIZED, "Credenciales inválidas"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
        }

        if (!user.getActive()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Usuario desactivado");
        }

        return buildAuthResponse(user);
    }

    public AuthDtos.AuthResponse refresh(AuthDtos.RefreshRequest request) {
        if (!jwtService.isValid(request.refreshToken())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Refresh token inválido");
        }

        if (!"REFRESH".equals(jwtService.extractType(request.refreshToken()))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El token proporcionado no es un refresh token");
        }

        String email = jwtService.extractEmail(request.refreshToken());
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.UNAUTHORIZED, "Usuario no encontrado"));

        return buildAuthResponse(user);
    }

    private AuthDtos.AuthResponse buildAuthResponse(User user) {
        return new AuthDtos.AuthResponse(
                jwtService.generateAccessToken(user),
                jwtService.generateRefreshToken(user),
                accessTokenExpiration,
                new AuthDtos.UserInfo(
                        user.getId(),
                        user.getEmail(),
                        user.getFullName(),
                        user.getRole(),
                        user.getLocale()
                )
        );
    }
}
