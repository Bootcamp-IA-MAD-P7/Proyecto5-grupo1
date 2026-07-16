package com.sentilife.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sentilife.alerts.Alert;
import com.sentilife.alerts.AlertRepository;
import com.sentilife.alerts.FeedbackLabelRepository;
import com.sentilife.config.DomainExceptions;
import com.sentilife.monitored.MonitoredPerson;
import com.sentilife.monitored.MonitoredPersonRepository;
import com.sentilife.telemetry.TelemetryWindowRepository;
import com.sentilife.users.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminServiceTest {

    @Mock AlertRepository alertRepository;
    @Mock FeedbackLabelRepository feedbackRepository;
    @Mock MonitoredPersonRepository monitoredPersonRepository;
    @Mock TelemetryWindowRepository telemetryRepository;
    @Mock UserRepository userRepository;
    @Mock ObjectMapper objectMapper;

    @InjectMocks AdminService service;

    @Test
    void getHistory_passesPersonAndFeedbackFiltersToRepository() {
        UUID personId = UUID.randomUUID();
        UUID alertId = UUID.randomUUID();
        Alert alert = org.mockito.Mockito.mock(Alert.class);
        when(alert.getId()).thenReturn(alertId);
        when(alert.getMonitoredPersonId()).thenReturn(personId);
        when(alert.getDetectedAt()).thenReturn(Instant.now());
        when(alert.getConfidence()).thenReturn(BigDecimal.valueOf(0.9));
        when(alert.getModelVersion()).thenReturn("v1");
        when(alert.getStatus()).thenReturn("CONFIRMED");

        MonitoredPerson ana = person("Ana", personId);
        when(alertRepository.findForAdminHistory(
                eq(personId), eq(true), eq("TRUE_FALL"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(alert)));
        when(monitoredPersonRepository.findById(personId)).thenReturn(Optional.of(ana));
        when(feedbackRepository.findByAlertId(alertId)).thenReturn(Optional.empty());

        Page<AdminDtos.HistoryEntry> page = service.getHistory(
                personId, true, "true_fall", PageRequest.of(0, 20));

        assertThat(page.getContent()).hasSize(1);
        ArgumentCaptor<Pageable> pageableCaptor = ArgumentCaptor.forClass(Pageable.class);
        verify(alertRepository).findForAdminHistory(
                eq(personId), eq(true), eq("TRUE_FALL"), pageableCaptor.capture());
        assertThat(pageableCaptor.getValue().getSort().getOrderFor("detectedAt").getDirection())
                .isEqualTo(Sort.Direction.DESC);
    }

    @Test
    void getHistory_rejectsInvalidFeedbackLabel() {
        assertThatThrownBy(() -> service.getHistory(
                null, true, "MAYBE", PageRequest.of(0, 20)))
                .isInstanceOf(DomainExceptions.BadRequestException.class);
    }

    @Test
    void listMonitoredPersons_sortedByFullName() {
        UUID idA = UUID.randomUUID();
        UUID idB = UUID.randomUUID();
        MonitoredPerson ana = person("Ana", idA);
        MonitoredPerson bruno = person("Bruno", idB);
        when(monitoredPersonRepository.findAll(any(Sort.class)))
                .thenReturn(List.of(ana, bruno));

        List<AdminDtos.MonitoredPersonOption> options = service.listMonitoredPersons();

        assertThat(options).extracting(AdminDtos.MonitoredPersonOption::fullName)
                .containsExactly("Ana", "Bruno");
        verify(monitoredPersonRepository)
                .findAll(Sort.by(Sort.Direction.ASC, "fullName"));
    }

    private static MonitoredPerson person(String name, UUID id) {
        MonitoredPerson p = org.mockito.Mockito.mock(MonitoredPerson.class);
        org.mockito.Mockito.lenient().when(p.getId()).thenReturn(id);
        org.mockito.Mockito.lenient().when(p.getFullName()).thenReturn(name);
        return p;
    }
}
