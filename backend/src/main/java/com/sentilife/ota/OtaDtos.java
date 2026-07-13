package com.sentilife.ota;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public final class OtaDtos {

    private OtaDtos() {}

    public record RegisterRequest(
            @NotNull @JsonProperty("version_code") Integer versionCode,
            @NotBlank @JsonProperty("version_name") String versionName,
            @NotBlank @JsonProperty("apk_url") String apkUrl,
            @JsonProperty("release_notes") String releaseNotes
    ) {}

    public record LatestVersionResponse(
            @JsonProperty("version_code") Integer versionCode,
            @JsonProperty("version_name") String versionName,
            @JsonProperty("apk_url") String apkUrl,
            @JsonProperty("release_notes") String releaseNotes,
            @JsonProperty("min_supported_version_code") Integer minSupportedVersionCode
    ) {}
}
