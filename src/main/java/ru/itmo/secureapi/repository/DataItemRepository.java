package ru.itmo.secureapi.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.itmo.secureapi.model.DataItem;

import java.util.List;

public interface DataItemRepository extends JpaRepository<DataItem, Long> {

    List<DataItem> findAllByOrderByCreatedAtDesc();
}
