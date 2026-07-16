package com.sentilife.assistant;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Assistant API contracts — spec §6.9 (RF-46, RF-47) + TTS extension.
 */
public final class AssistantDtos {

    private AssistantDtos() {}

    public record ChatRequest(
            @NotBlank @Size(max = 4000) String message,
            String conversationId,
            String locale,
            Boolean tts
    ) {}

    public record ChatResponse(
            String reply,
            List<String> sources,
            List<String> toolsUsed,
            String conversationId,
            String audioBase64,
            String contentType,
            String voiceId
    ) {}

    public record TranscribeResponse(String text, String language) {}

    public record SpeakRequest(@NotBlank @Size(max = 4000) String text) {}

    public record SpeakResponse(String audioBase64, String contentType, String voiceId) {}
}
