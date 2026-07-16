package com.sentilife.assistant;

import com.sentilife.config.DomainExceptions;
import com.sentilife.users.User;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

/**
 * Assistant proxy — spec §6.9 (RF-46, RF-47).
 *
 * Authenticated (any role). Role is taken from JWT (never from client body).
 * Forwards Authorization so the agent can call role-scoped Java tools.
 */
@RestController
@RequestMapping("/api/v1/assistant")
public class AssistantController {

    private static final long MAX_AUDIO_BYTES = 5L * 1024 * 1024;

    private final AssistantService service;

    public AssistantController(AssistantService service) {
        this.service = service;
    }

    @PostMapping("/chat")
    public ResponseEntity<AssistantDtos.ChatResponse> chat(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody AssistantDtos.ChatRequest request,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return ResponseEntity.ok(service.chat(user, request, authorization));
    }

    @PostMapping(value = "/transcribe", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<AssistantDtos.TranscribeResponse> transcribe(
            @AuthenticationPrincipal User user,
            @RequestPart("audio") MultipartFile audio) throws IOException {
        if (audio == null || audio.isEmpty()) {
            throw DomainExceptions.BadRequestException.of("Campo audio requerido");
        }
        if (audio.getSize() > MAX_AUDIO_BYTES) {
            throw DomainExceptions.BadRequestException.of(
                    "Audio demasiado grande (máximo 5 MB / ~30 s)");
        }
        return ResponseEntity.ok(service.transcribe(audio.getBytes(), audio.getOriginalFilename()));
    }

    @PostMapping("/speak")
    public ResponseEntity<AssistantDtos.SpeakResponse> speak(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody AssistantDtos.SpeakRequest request) {
        return ResponseEntity.ok(service.speak(request));
    }
}
