package ru.itmo.secureapi.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DataRequest(
        @NotBlank @Size(max = 100) String title,
        @NotBlank @Size(max = 500) String content
) {
}
