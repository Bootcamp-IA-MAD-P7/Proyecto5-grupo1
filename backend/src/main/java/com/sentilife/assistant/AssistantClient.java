package com.sentilife.assistant;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.config.DomainExceptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * HTTP client for the FastAPI assistant agent (internal network only).
 */
@Component
public class AssistantClient {

    private static final Logger log = LoggerFactory.getLogger(AssistantClient.class);

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String baseUrl;

    @Autowired
    public AssistantClient(
            @Value("${sentilife.assistant.url}") String assistantUrl,
            ObjectMapper objectMapper) {
        this(assistantUrl, objectMapper, new RestTemplate());
    }

    /** Package-private for unit tests with a mock {@link RestTemplate}. */
    AssistantClient(String assistantUrl, ObjectMapper objectMapper, RestTemplate restTemplate) {
        this.baseUrl = assistantUrl.replaceAll("/$", "");
        this.objectMapper = objectMapper;
        this.restTemplate = restTemplate;
    }

    public AssistantDtos.ChatResponse chat(
            String message,
            String role,
            String locale,
            String conversationId,
            boolean tts,
            String authorizationHeader) {

        Map<String, Object> body = new HashMap<>();
        body.put("message", message);
        body.put("role", role);
        body.put("locale", locale != null ? locale : "es");
        body.put("tts", tts);
        if (conversationId != null) {
            body.put("conversationId", conversationId);
        }

        HttpHeaders headers = jsonHeaders(authorizationHeader);
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate.postForObject(
                    baseUrl + "/assistant/chat",
                    new HttpEntity<>(objectMapper.writeValueAsString(body), headers),
                    Map.class);
            return toChatResponse(resp);
        } catch (HttpStatusCodeException ex) {
            throw mapHttpError(ex);
        } catch (RestClientException | com.fasterxml.jackson.core.JsonProcessingException ex) {
            log.error("Assistant chat unreachable: {}", ex.getMessage());
            throw DomainExceptions.ServiceUnavailableException.of(
                    "Servicio asistente no disponible");
        }
    }

    public AssistantDtos.TranscribeResponse transcribe(byte[] audio, String filename) {
        // IMPORTANT: do NOT set Content-Type to multipart/form-data manually.
        // RestTemplate must add the boundary parameter; without it FastAPI receives
        // a broken body and Whisper returns empty / 400.
        String safeName = (filename != null && !filename.isBlank()) ? filename : "audio.wav";

        ByteArrayResource resource = new ByteArrayResource(audio) {
            @Override
            public String getFilename() {
                return safeName;
            }
        };

        HttpHeaders partHeaders = new HttpHeaders();
        partHeaders.setContentType(guessAudioMediaType(safeName));
        MultiValueMap<String, Object> multipart = new LinkedMultiValueMap<>();
        multipart.add("audio", new HttpEntity<>(resource, partHeaders));

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate.postForObject(
                    baseUrl + "/assistant/transcribe",
                    new HttpEntity<>(multipart),
                    Map.class);
            if (resp == null) {
                throw DomainExceptions.ServiceUnavailableException.of("Transcripción vacía");
            }
            return new AssistantDtos.TranscribeResponse(
                    String.valueOf(resp.getOrDefault("text", "")),
                    String.valueOf(resp.getOrDefault("language", "es")));
        } catch (HttpStatusCodeException ex) {
            throw mapHttpError(ex);
        } catch (RestClientException ex) {
            log.error("Assistant transcribe unreachable: {}", ex.getMessage());
            throw DomainExceptions.ServiceUnavailableException.of(
                    "Servicio de transcripción no disponible");
        }
    }

    public AssistantDtos.SpeakResponse speak(String text) {
        Map<String, Object> body = Map.of("text", text);
        HttpHeaders headers = jsonHeaders(null);
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate.postForObject(
                    baseUrl + "/assistant/speak",
                    new HttpEntity<>(objectMapper.writeValueAsString(body), headers),
                    Map.class);
            if (resp == null || resp.get("audioBase64") == null) {
                throw DomainExceptions.ServiceUnavailableException.of("TTS vacío");
            }
            return new AssistantDtos.SpeakResponse(
                    String.valueOf(resp.get("audioBase64")),
                    String.valueOf(resp.getOrDefault("contentType", "audio/mpeg")),
                    String.valueOf(resp.getOrDefault("voiceId", "")));
        } catch (HttpStatusCodeException ex) {
            throw mapHttpError(ex);
        } catch (RestClientException | com.fasterxml.jackson.core.JsonProcessingException ex) {
            log.error("Assistant speak unreachable: {}", ex.getMessage());
            throw DomainExceptions.ServiceUnavailableException.of("TTS no disponible");
        }
    }

    private static HttpHeaders jsonHeaders(String authorizationHeader) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (authorizationHeader != null && !authorizationHeader.isBlank()) {
            headers.set(HttpHeaders.AUTHORIZATION, authorizationHeader);
        }
        return headers;
    }

    private static MediaType guessAudioMediaType(String filename) {
        String lower = filename.toLowerCase();
        if (lower.endsWith(".wav")) {
            return MediaType.parseMediaType("audio/wav");
        }
        if (lower.endsWith(".webm")) {
            return MediaType.parseMediaType("audio/webm");
        }
        if (lower.endsWith(".mp3")) {
            return MediaType.parseMediaType("audio/mpeg");
        }
        if (lower.endsWith(".m4a") || lower.endsWith(".aac") || lower.endsWith(".mp4")) {
            return MediaType.parseMediaType("audio/mp4");
        }
        return MediaType.APPLICATION_OCTET_STREAM;
    }

    @SuppressWarnings("unchecked")
    private static AssistantDtos.ChatResponse toChatResponse(Map<String, Object> resp) {
        if (resp == null) {
            throw DomainExceptions.ServiceUnavailableException.of("Respuesta vacía del asistente");
        }
        List<String> sources = castStringList(resp.get("sources"));
        List<String> tools = castStringList(resp.get("toolsUsed"));
        return new AssistantDtos.ChatResponse(
                String.valueOf(resp.getOrDefault("reply", "")),
                sources,
                tools,
                resp.get("conversationId") != null ? String.valueOf(resp.get("conversationId")) : null,
                resp.get("audioBase64") != null ? String.valueOf(resp.get("audioBase64")) : null,
                resp.get("contentType") != null ? String.valueOf(resp.get("contentType")) : null,
                resp.get("voiceId") != null ? String.valueOf(resp.get("voiceId")) : null
        );
    }

    private static List<String> castStringList(Object value) {
        if (!(value instanceof List<?> list)) {
            return List.of();
        }
        return list.stream().map(String::valueOf).toList();
    }

    private RuntimeException mapHttpError(HttpStatusCodeException ex) {
        int status = ex.getStatusCode().value();
        String detail = ex.getResponseBodyAsString();
        if (detail != null && detail.length() > 300) {
            detail = detail.substring(0, 300);
        }
        if (status == 503) {
            return DomainExceptions.ServiceUnavailableException.of(
                    detail != null && !detail.isBlank()
                            ? detail
                            : "GROQ_API_KEY no configurada o asistente no disponible");
        }
        if (status == 400) {
            return DomainExceptions.BadRequestException.of(
                    detail != null ? detail : "Petición inválida al asistente");
        }
        log.warn("Assistant upstream HTTP {}: {}", status, detail);
        return DomainExceptions.ServiceUnavailableException.of(
                "Error del asistente (HTTP " + status + ")");
    }
}
