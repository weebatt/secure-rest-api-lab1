package ru.itmo.secureapi;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import ru.itmo.secureapi.repository.UserRepository;

import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecureApiIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Test
    void loginReturnsJwtToken() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"student","password":"StrongPassword123!"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresInSeconds").value(900));
    }

    @Test
    void passwordIsStoredOnlyAsBcryptHash() {
        String passwordHash = userRepository.findByUsername("student").orElseThrow().getPasswordHash();

        assertNotEquals("StrongPassword123!", passwordHash);
        assertTrue(passwordHash.startsWith("$2"));
    }

    @Test
    void protectedEndpointRejectsMissingToken() throws Exception {
        mockMvc.perform(get("/api/data"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("Authentication is required"));
    }

    @Test
    void protectedEndpointRejectsMalformedToken() throws Exception {
        mockMvc.perform(get("/api/data")
                        .header("Authorization", "Bearer not-a-valid-jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("Invalid or expired JWT token"));
    }

    @Test
    void sqlInjectionPayloadCannotBypassAuthentication() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"' OR '1'='1","password":"anything"}
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void authenticatedUserCanReadData() throws Exception {
        String token = loginAndGetToken();

        mockMvc.perform(get("/api/data")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].title").isNotEmpty());
    }

    @Test
    void userContentIsEscapedBeforeItIsReturned() throws Exception {
        String token = loginAndGetToken();

        mockMvc.perform(post("/api/data")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"<script>alert('xss')</script>","content":"<b>unsafe</b>"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title", containsString("&lt;script&gt;")))
                .andExpect(jsonPath("$.content").value("&lt;b&gt;unsafe&lt;/b&gt;"))
                .andExpect(content().string(not(containsString("<script>"))));
    }

    @Test
    void validationRejectsOversizedInput() throws Exception {
        String token = loginAndGetToken();
        String longTitle = "x".repeat(101);

        mockMvc.perform(post("/api/data")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new TestDataRequest(longTitle, "content"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Validation failed"))
                .andExpect(jsonPath("$.details.title").exists());
    }

    private String loginAndGetToken() throws Exception {
        String body = mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"student","password":"StrongPassword123!"}
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        JsonNode json = objectMapper.readTree(body);
        return json.get("token").asText();
    }

    private record TestDataRequest(String title, String content) {
    }
}
