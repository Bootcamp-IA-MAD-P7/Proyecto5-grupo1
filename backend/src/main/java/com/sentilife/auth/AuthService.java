package com.sentilife.auth;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import com.sentilife.config.JwtService;
import com.sentilife.users.User;
import com.sentilife.users.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final int accessTokenExpiration;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       @Value("${sentilife.jwt.access-token-expiration}") int accessExpiration) {
        this.userRepository        = userRepository;
        this.passwordEncoder       = passwordEncoder;
        this.jwtService            = jwtService;
        this.accessTokenExpiration = accessExpiration;
    }

    @Transactional
    public AuthDtos.AuthResponse register(AuthDtos.RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw DomainExceptions.ConflictException.of("Email ya registrado");
        }
        if (request.password().length() < 8) {
            throw DomainExceptions.BadRequestException.of(
                    "La contraseña debe tener al menos 8 caracteres");
        }

        User user = new User();
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setFullName(request.fullName());
        user.setRole(request.role());
        user.setLocale(request.locale() != null ? request.locale() : DomainConstants.DEFAULT_LOCALE);
        user.setActive(true);
        user = userRepository.save(user);

        return buildAuthResponse(user);
    }

    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
                .orElseThrow(() -> DomainExceptions.UnauthorizedException.of("Credenciales inválidas"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw DomainExceptions.UnauthorizedException.of("Credenciales inválidas");
        }
        if (!user.getActive()) {
            throw DomainExceptions.ForbiddenException.of("Usuario desactivado");
        }

        return buildAuthResponse(user);
    }

    public AuthDtos.AuthResponse refresh(AuthDtos.RefreshRequest request) {
        if (!jwtService.isValid(request.refreshToken())) {
            throw DomainExceptions.UnauthorizedException.of("Refresh token inválido");
        }
        if (!DomainConstants.TOKEN_REFRESH.equals(jwtService.extractType(request.refreshToken()))) {
            throw DomainExceptions.BadRequestException.of("El token proporcionado no es un refresh token");
        }

        String email = jwtService.extractEmail(request.refreshToken());
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> DomainExceptions.UnauthorizedException.of("Usuario no encontrado"));

        return buildAuthResponse(user);
    }

    private AuthDtos.AuthResponse buildAuthResponse(User user) {
        return new AuthDtos.AuthResponse(
                jwtService.generateAccessToken(user),
                jwtService.generateRefreshToken(user),
                accessTokenExpiration,
                new AuthDtos.UserInfo(user.getId(), user.getEmail(),
                        user.getFullName(), user.getRole(), user.getLocale())
        );
    }
}
