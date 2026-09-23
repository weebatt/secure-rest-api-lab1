package ru.itmo.secureapi.dto;

import java.time.Instant;
import java.util.Map;

public final class ErrorResponse {

    private final Instant timestamp;
    private final int status;
    private final String error;
    private final Map<String, String> details;

    public ErrorResponse(Instant timestamp, int status, String error, Map<String, String> details) {
        this.timestamp = timestamp;
        this.status = status;
        this.error = error;
        this.details = Map.copyOf(details);
    }

    public static ErrorResponse of(int status, String error) {
        return new ErrorResponse(Instant.now(), status, error, Map.of());
    }

    public Instant getTimestamp() {
        return timestamp;
    }

    public int getStatus() {
        return status;
    }

    public String getError() {
        return error;
    }

    public Map<String, String> getDetails() {
        return Map.copyOf(details);
    }
}
