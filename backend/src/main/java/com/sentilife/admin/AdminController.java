package com.sentilife.admin;

import com.sentilife.users.User;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Admin controller — IT_ADMIN role only — spec §6.6.
 *
 * GET   /api/v1/admin/history          — global alert + feedback history
 * GET   /api/v1/admin/export           — labelled dataset as CSV
 * GET   /api/v1/admin/users            — list all users
 * PATCH /api/v1/admin/users/{id}       — activate / deactivate user
 *
 * Retrain endpoints moved to RetrainController (SL-55).
 * Model registry endpoints in RegistryController (SL-54).
 */
@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('IT_ADMIN')")
public class AdminController {

    private final AdminService service;

    public AdminController(AdminService service) {
        this.service = service;
    }

    @GetMapping("/history")
    public ResponseEntity<Page<AdminDtos.HistoryEntry>> history(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(service.getHistory(pageable));
    }

    /**
     * Exports the labelled dataset as CSV for ML retraining.
     * Optional date range: ?from=2026-07-01T00:00:00Z&to=2026-07-10T00:00:00Z
     */
    @GetMapping("/export")
    public ResponseEntity<String> export(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {

        List<AdminDtos.ExportRow> rows = service.exportLabelledDataset(from, to);
        String csv = toCsv(rows);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"sentilife_dataset.csv\"")
                .contentType(MediaType.parseMediaType("text/csv"))
                .body(csv);
    }

    @GetMapping("/users")
    public ResponseEntity<Page<AdminDtos.UserSummary>> listUsers(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(service.listUsers(pageable));
    }

    @PatchMapping("/users/{id}")
    public ResponseEntity<AdminDtos.UserSummary> setUserActive(
            @PathVariable UUID id,
            @Valid @RequestBody AdminDtos.UserStatusRequest request) {
        return ResponseEntity.ok(service.setUserActive(id, request));
    }

    // ── CSV helper ────────────────────────────────────────────────────────────

    private String toCsv(List<AdminDtos.ExportRow> rows) {
        StringBuilder sb = new StringBuilder();
        sb.append("window_id,monitored_person_id,window_start,window_end," +
                  "sample_rate_hz,samples_json,label\n");
        rows.forEach(r -> sb.append(String.join(",",
                r.windowId().toString(),
                r.monitoredPersonId().toString(),
                r.windowStart().toString(),
                r.windowEnd().toString(),
                String.valueOf(r.sampleRateHz()),
                "\"" + r.samplesJson().replace("\"", "\"\"") + "\"",
                r.label()
        )).append("\n"));
        return sb.toString();
    }
}
