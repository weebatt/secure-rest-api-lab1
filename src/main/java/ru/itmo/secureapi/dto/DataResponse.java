package ru.itmo.secureapi.dto;

import org.springframework.web.util.HtmlUtils;
import ru.itmo.secureapi.model.DataItem;

import java.time.Instant;

public record DataResponse(Long id, String title, String content, String owner, Instant createdAt) {

    public static DataResponse from(DataItem item) {
        return new DataResponse(
                item.getId(),
                HtmlUtils.htmlEscape(item.getTitle()),
                HtmlUtils.htmlEscape(item.getContent()),
                HtmlUtils.htmlEscape(item.getOwner()),
                item.getCreatedAt()
        );
    }
}
