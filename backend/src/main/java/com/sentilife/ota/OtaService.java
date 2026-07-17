package com.sentilife.ota;

import com.sentilife.config.DomainExceptions;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OtaService {

    private final AppVersionRepository repository;

    public OtaService(AppVersionRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public OtaDtos.LatestVersionResponse latestVersion() {
        var latest = repository.findTopByOrderByVersionCodeDesc()
                .orElseThrow(() -> DomainExceptions.NotFoundException.of("No hay versiones publicadas."));
        return toResponse(latest);
    }

    @Transactional
    public OtaDtos.LatestVersionResponse register(OtaDtos.RegisterRequest request) {
        var entity = repository.findByVersionCode(request.versionCode()).orElseGet(AppVersion::new);
        entity.setVersionCode(request.versionCode());
        entity.setVersionName(request.versionName());
        entity.setApkUrl(request.apkUrl());
        entity.setReleaseNotes(request.releaseNotes());
        return toResponse(repository.save(entity));
    }

    private static OtaDtos.LatestVersionResponse toResponse(AppVersion v) {
        return new OtaDtos.LatestVersionResponse(
                v.getVersionCode(),
                v.getVersionName(),
                v.getApkUrl(),
                v.getReleaseNotes(),
                null
        );
    }
}
