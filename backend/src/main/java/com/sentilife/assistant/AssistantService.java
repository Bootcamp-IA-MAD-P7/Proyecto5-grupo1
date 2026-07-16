package com.sentilife.assistant;

import com.sentilife.users.User;
import org.springframework.stereotype.Service;

@Service
public class AssistantService {

    private final AssistantClient client;

    public AssistantService(AssistantClient client) {
        this.client = client;
    }

    public AssistantDtos.ChatResponse chat(
            User user,
            AssistantDtos.ChatRequest request,
            String authorizationHeader) {
        boolean tts = Boolean.TRUE.equals(request.tts());
        String locale = request.locale() != null ? request.locale() : user.getLocale();
        return client.chat(
                request.message(),
                user.getRole(),
                locale,
                request.conversationId(),
                tts,
                authorizationHeader
        );
    }

    public AssistantDtos.TranscribeResponse transcribe(byte[] audio, String filename) {
        return client.transcribe(audio, filename);
    }

    public AssistantDtos.SpeakResponse speak(AssistantDtos.SpeakRequest request) {
        return client.speak(request.text());
    }
}
