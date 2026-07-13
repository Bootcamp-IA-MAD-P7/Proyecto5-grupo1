package com.sentilife.registry;

import com.sentilife.config.DomainConstants;
import com.sentilife.config.DomainExceptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.util.List;

/**
 * Business logic for model version management.
 *
 * Register: saves a new model as CANDIDATE.
 * Promote: sets a CANDIDATE as ACTIVE, retires the previous ACTIVE,
 *          and triggers hot-reload on the inference service.
 * List: returns all versions ordered by creation date.
 */
@Service
public class RegistryService {

    private static final Logger log = LoggerFactory.getLogger(RegistryService.class);

    private static final String STATUS_ACTIVE = DomainConstants.MODEL_ACTIVE;
    private static final String STATUS_CANDIDATE = DomainConstants.MODEL_CANDIDATE;
    private static final String STATUS_RETIRED = DomainConstants.MODEL_RETIRED;

    private final ModelVersionRepository repository;
    private final RestTemplate restTemplate;
    private final String inferenceUrl;

    public RegistryService(ModelVersionRepository repository,
                           @Value("${sentilife.inference.url}") String inferenceUrl) {
        this.repository = repository;
        this.restTemplate = new RestTemplate();
        this.inferenceUrl = inferenceUrl;
    }

    /**
     * Registers a new model version as CANDIDATE.
     */
    @Transactional
    public RegistryDtos.ModelVersionResponse register(RegistryDtos.RegisterRequest request) {
        if (repository.findByVersion(request.version()).isPresent()) {
            throw DomainExceptions.ConflictException.of(
                    "Model version already exists: " + request.version());
        }

        ModelVersion model = new ModelVersion();
        model.setVersion(request.version());
        model.setAlgorithm(request.algorithm());
        model.setMetricsJson(request.metrics());
        model.setArtifactUri(request.artifactUri());
        model.setStatus(STATUS_CANDIDATE);
        model = repository.save(model);

        log.info("[Registry] Registered new model: {} ({})", request.version(), request.algorithm());
        return toResponse(model);
    }

    /**
     * Promotes a CANDIDATE to ACTIVE. Retires the current ACTIVE.
     * Triggers hot-reload on the inference service.
     */
    @Transactional
    public RegistryDtos.PromoteResponse promote(String version) {
        ModelVersion candidate = repository.findByVersion(version)
                .orElseThrow(() -> DomainExceptions.NotFoundException.of(
                        "Model version not found: " + version));

        if (STATUS_ACTIVE.equals(candidate.getStatus())) {
            throw DomainExceptions.BadRequestException.of("Model is already ACTIVE");
        }
        if (STATUS_RETIRED.equals(candidate.getStatus())) {
            throw DomainExceptions.BadRequestException.of("Cannot promote a RETIRED model");
        }

        // Retire the current active model (if any)
        String previousActive = null;
        var currentActive = repository.findByStatus(STATUS_ACTIVE);
        if (currentActive.isPresent()) {
            var active = currentActive.get();
            active.setStatus(STATUS_RETIRED);
            repository.save(active);
            previousActive = active.getVersion();
            log.info("[Registry] Retired model: {}", previousActive);
        }

        // Promote the candidate
        candidate.setStatus(STATUS_ACTIVE);
        repository.save(candidate);
        log.info("[Registry] Promoted model: {}", version);

        // Trigger hot-reload on inference service
        boolean reloaded = triggerReload(candidate.getArtifactUri());

        return new RegistryDtos.PromoteResponse(version, previousActive, reloaded);
    }

    /**
     * Returns all model versions ordered by creation date (newest first).
     */
    public List<RegistryDtos.ModelVersionResponse> listAll() {
        return repository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::toResponse)
                .toList();
    }

    /**
     * Returns the currently active model version.
     */
    public RegistryDtos.ModelVersionResponse getActive() {
        return repository.findByStatus(STATUS_ACTIVE)
                .map(this::toResponse)
                .orElseThrow(() -> DomainExceptions.NotFoundException.of("No active model"));
    }

    /**
     * Calls POST /model/reload on the inference service to load the new model.
     * Returns true if successful, false if it failed (non-blocking).
     */
    private boolean triggerReload(String artifactUri) {
        try {
            String url = inferenceUrl + "/model/reload?path=" + artifactUri;
            ResponseEntity<String> response = restTemplate.postForEntity(url, null, String.class);
            if (response.getStatusCode().is2xxSuccessful()) {
                log.info("[Registry] Inference service reloaded model from: {}", artifactUri);
                return true;
            }
            log.warn("[Registry] Inference reload returned {}", response.getStatusCode());
            return false;
        } catch (Exception e) {
            log.error("[Registry] Failed to trigger reload: {}", e.getMessage());
            return false;
        }
    }

    private RegistryDtos.ModelVersionResponse toResponse(ModelVersion m) {
        return new RegistryDtos.ModelVersionResponse(
                m.getId(), m.getVersion(), m.getAlgorithm(),
                m.getMetricsJson(), m.getArtifactUri(),
                m.getStatus(), m.getCreatedAt()
        );
    }
}
