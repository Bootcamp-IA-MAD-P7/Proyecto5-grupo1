package com.sentilife.ota;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.file.Files;
import java.nio.file.Path;

/**
 * OTA Android — rutas legacy /app/* usadas por Flutter y CI.
 */
@RestController
@RequestMapping("/app")
public class OtaController {

    private final OtaService service;
    private final Path apkPath;

    public OtaController(
            OtaService service,
            @Value("${sentilife.ota.apk-path:/ota/app-release.apk}") String apkPath) {
        this.service = service;
        this.apkPath = Path.of(apkPath);
    }

    @GetMapping("/latest-version")
    public OtaDtos.LatestVersionResponse latestVersion() {
        return service.latestVersion();
    }

    @PostMapping("/register-version")
    public ResponseEntity<OtaDtos.LatestVersionResponse> register(
            @Valid @RequestBody OtaDtos.RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.register(request));
    }

    /**
     * Descarga el APK publicado por CI en EC2 (no depende de GitHub Releases).
     */
    @GetMapping("/download.apk")
    public ResponseEntity<Resource> downloadApk() {
        if (!Files.isRegularFile(apkPath)) {
            return ResponseEntity.notFound().build();
        }
        Resource body = new FileSystemResource(apkPath);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"app-release.apk\"")
                .contentType(MediaType.parseMediaType("application/vnd.android.package-archive"))
                .body(body);
    }
}
