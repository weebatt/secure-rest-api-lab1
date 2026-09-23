package ru.itmo.secureapi.dto;

public record LoginResponse(String token, String tokenType, long expiresInSeconds) {
}
