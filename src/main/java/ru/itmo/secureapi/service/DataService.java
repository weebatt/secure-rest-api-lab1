package ru.itmo.secureapi.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ru.itmo.secureapi.dto.DataRequest;
import ru.itmo.secureapi.dto.DataResponse;
import ru.itmo.secureapi.model.DataItem;
import ru.itmo.secureapi.repository.DataItemRepository;

import java.util.List;

@Service
public class DataService {

    private final DataItemRepository dataItemRepository;

    public DataService(DataItemRepository dataItemRepository) {
        this.dataItemRepository = dataItemRepository;
    }

    @Transactional(readOnly = true)
    public List<DataResponse> findAll() {
        return dataItemRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(DataResponse::from)
                .toList();
    }

    @Transactional
    public DataResponse create(DataRequest request, String owner) {
        DataItem saved = dataItemRepository.save(new DataItem(request.title(), request.content(), owner));
        return DataResponse.from(saved);
    }
}
