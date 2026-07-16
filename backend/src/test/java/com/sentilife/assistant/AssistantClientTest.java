package com.sentilife.assistant;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.config.DomainExceptions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AssistantClientTest {

    private RestTemplate restTemplate;
    private AssistantClient client;

    @BeforeEach
    void setUp() {
        restTemplate = mock(RestTemplate.class);
        client = new AssistantClient("http://assistant:8001", new ObjectMapper(), restTemplate);
    }

    @Test
    void chatMapsResponse() {
        when(restTemplate.postForObject(eq("http://assistant:8001/assistant/chat"),
                any(HttpEntity.class), eq(Map.class)))
                .thenReturn(Map.of(
                        "reply", "Hay 7 registros",
                        "sources", List.of("docs/x.md"),
                        "toolsUsed", List.of("get_retrain_prerequisites")
                ));

        var resp = client.chat("¿puedo reentrenar?", "IT_ADMIN", "es", null, false, "Bearer t");
        assertEquals("Hay 7 registros", resp.reply());
        assertEquals(List.of("docs/x.md"), resp.sources());
        assertEquals(List.of("get_retrain_prerequisites"), resp.toolsUsed());
    }

    @Test
    void chat503MapsToServiceUnavailable() {
        when(restTemplate.postForObject(anyString(), any(HttpEntity.class), eq(Map.class)))
                .thenThrow(HttpClientErrorException.create(
                        HttpStatus.SERVICE_UNAVAILABLE,
                        "Unavailable",
                        null,
                        "{\"detail\":\"GROQ_API_KEY no configurada\"}".getBytes(StandardCharsets.UTF_8),
                        StandardCharsets.UTF_8));

        assertThrows(DomainExceptions.ServiceUnavailableException.class,
                () -> client.chat("hola", "CAREGIVER", "es", null, false, "Bearer t"));
    }
}
