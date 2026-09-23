package ru.itmo.secureapi.controller;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.itmo.secureapi.dto.DataRequest;
import ru.itmo.secureapi.dto.DataResponse;
import ru.itmo.secureapi.service.DataService;

import java.util.List;

@RestController
@RequestMapping("/api/data")
public class DataController {

    private final DataService dataService;

    public DataController(DataService dataService) {
        this.dataService = dataService;
    }

    @GetMapping
    public ResponseEntity<List<DataResponse>> getData() {
        return ResponseEntity.ok(dataService.findAll());
    }

    @PostMapping
    public ResponseEntity<DataResponse> createData(
            @Valid @RequestBody DataRequest request,
            Authentication authentication
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(dataService.create(request, authentication.getName()));
    }
}
