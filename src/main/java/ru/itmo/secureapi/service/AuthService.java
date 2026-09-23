package ru.itmo.secureapi.service;

import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Service;
import ru.itmo.secureapi.dto.LoginRequest;
import ru.itmo.secureapi.dto.LoginResponse;
import ru.itmo.secureapi.security.JwtService;

@Service
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;

    public AuthService(AuthenticationManager authenticationManager, JwtService jwtService) {
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
    }

    public LoginResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.username(), request.password())
        );
        return new LoginResponse(
                jwtService.generateToken(request.username()),
                "Bearer",
                jwtService.getExpirationSeconds()
        );
    }
}
