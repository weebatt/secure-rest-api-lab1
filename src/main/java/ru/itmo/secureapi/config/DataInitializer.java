package ru.itmo.secureapi.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;
import ru.itmo.secureapi.model.AppUser;
import ru.itmo.secureapi.model.DataItem;
import ru.itmo.secureapi.repository.DataItemRepository;
import ru.itmo.secureapi.repository.UserRepository;

@Configuration
public class DataInitializer {

    @Bean
    CommandLineRunner seedData(
            UserRepository userRepository,
            DataItemRepository dataItemRepository,
            PasswordEncoder passwordEncoder,
            @Value("${app.default-user.username:student}") String defaultUsername,
            @Value("${app.default-user.password}") String defaultPassword
    ) {
        return args -> {
            if (!userRepository.existsByUsername(defaultUsername)) {
                userRepository.save(new AppUser(defaultUsername, passwordEncoder.encode(defaultPassword)));
            }
            if (dataItemRepository.count() == 0) {
                dataItemRepository.save(new DataItem(
                        "Welcome",
                        "Protected data is available only with a valid JWT token.",
                        defaultUsername
                ));
            }
        };
    }
}
