package com.sentilife.notifications;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;

@ExtendWith(MockitoExtension.class)
class CaregiverPushListenerTest {

    @Mock NotificationService notificationService;

    @InjectMocks CaregiverPushListener listener;

    @Test
    void onCaregiverNotification_monitoringStarted_delegatesToNotificationService() {
        UUID personId = UUID.randomUUID();
        listener.onCaregiverNotification(CaregiverNotificationEvent.monitoringStarted(personId));

        verify(notificationService).sendStatusNotification(
                CaregiverNotificationEvent.TYPE_MONITORING_STARTED, personId);
        verifyNoMoreInteractions(notificationService);
    }

    @Test
    void onCaregiverNotification_fallAlert_delegatesToFallAlert() {
        UUID personId = UUID.randomUUID();
        UUID alertId = UUID.randomUUID();
        listener.onCaregiverNotification(
                CaregiverNotificationEvent.fallAlert(alertId, personId, 0.9, "baseline-v1"));

        verify(notificationService).sendFallAlert(personId, alertId, 0.9);
    }
}
