package com.sentilife.telemetry;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.config.DomainExceptions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class InferenceClientTest {

    @Mock RestTemplate restTemplate;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void predict_failFastDisabled_returnsFallbackOnRestError() {
        when(restTemplate.postForObject(anyString(), any(), eq(Map.class)))
                .thenThrow(new RestClientException("connection refused"));

        var client = new InferenceClient("http://api:8000", false, objectMapper, restTemplate);

        var result = client.predict(
                UUID.randomUUID(), UUID.randomUUID(), 50,
                Map.of("accX", new double[]{0.1}), Map.of());

        assertThat(result.modelVersion()).isEqualTo("inference-unavailable");
        assertThat(result.fallDetected()).isFalse();
        assertThat(result.confidence()).isZero();
    }

    @Test
    void predict_failFastEnabled_throwsServiceUnavailableOnRestError() {
        when(restTemplate.postForObject(anyString(), any(), eq(Map.class)))
                .thenThrow(new RestClientException("connection refused"));

        var client = new InferenceClient("http://api:8000", true, objectMapper, restTemplate);

        assertThatThrownBy(() -> client.predict(
                UUID.randomUUID(), UUID.randomUUID(), 50,
                Map.of("accX", new double[]{0.1}), Map.of()))
                .isInstanceOf(DomainExceptions.ServiceUnavailableException.class)
                .hasMessageContaining("inference-unavailable");
    }

    @Test
    void predict_failFastEnabled_throwsOnNullResponse() {
        when(restTemplate.postForObject(anyString(), any(), eq(Map.class)))
                .thenReturn(null);

        var client = new InferenceClient("http://api:8000", true, objectMapper, restTemplate);

        assertThatThrownBy(() -> client.predict(
                UUID.randomUUID(), UUID.randomUUID(), 50,
                Map.of("accX", new double[]{0.1}), Map.of()))
                .isInstanceOf(DomainExceptions.ServiceUnavailableException.class)
                .hasMessageContaining("null-response");
    }

    @Test
    void predict_success_parsesResponse() {
        when(restTemplate.postForObject(anyString(), any(), eq(Map.class)))
                .thenReturn(Map.of(
                        "fallDetected", true,
                        "confidence", 0.87,
                        "modelVersion", "baseline-v1"));

        var client = new InferenceClient("http://api:8000", true, objectMapper, restTemplate);

        var result = client.predict(
                UUID.randomUUID(), UUID.randomUUID(), 50,
                Map.of("accX", new double[]{0.1}), Map.of());

        assertThat(result.fallDetected()).isTrue();
        assertThat(result.confidence()).isEqualTo(0.87);
        assertThat(result.modelVersion()).isEqualTo("baseline-v1");
        assertThat(result.latencyMs()).isGreaterThanOrEqualTo(0);
    }
}
