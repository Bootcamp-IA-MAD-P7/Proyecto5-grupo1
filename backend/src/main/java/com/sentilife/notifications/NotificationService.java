package com.sentilife.notifications;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.sentilife.devices.PushToken;
import com.sentilife.devices.PushTokenRepository;
import com.sentilife.monitored.MonitoredPerson;
import com.sentilife.monitored.MonitoredPersonRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

/**
 * Sends push notifications via Firebase Cloud Messaging.
 *
 * Called when an alert is created (fall detected).
 * Looks up the caregiver's registered FCM tokens and sends
 * a notification to all their devices.
 *
 * Gracefully degrades: if Firebase is not initialized (no service
 * account configured), notifications are silently skipped and
 * the alert remains available via GET /alerts (polling fallback).
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final FirebaseConfig firebaseConfig;
    private final PushTokenRepository pushTokenRepository;
    private final MonitoredPersonRepository monitoredPersonRepository;

    public NotificationService(FirebaseConfig firebaseConfig,
                               PushTokenRepository pushTokenRepository,
                               MonitoredPersonRepository monitoredPersonRepository) {
        this.firebaseConfig = firebaseConfig;
        this.pushTokenRepository = pushTokenRepository;
        this.monitoredPersonRepository = monitoredPersonRepository;
    }

    /**
     * Sends a fall alert push notification to the caregiver.
     *
     * @param monitoredPersonId the person who fell
     * @param alertId           the alert UUID (for navigation on tap)
     * @param confidence        prediction confidence (0-1)
     */
    public void sendFallAlert(UUID monitoredPersonId, UUID alertId, double confidence) {
        if (!firebaseConfig.isInitialized()) {
            log.debug("[FCM] Firebase not initialized — skipping push for alert={}", alertId);
            return;
        }

        // Find the caregiver for this monitored person
        MonitoredPerson person = monitoredPersonRepository.findById(monitoredPersonId)
                .orElse(null);
        if (person == null) {
            log.warn("[FCM] Monitored person not found: {}", monitoredPersonId);
            return;
        }

        UUID caregiverId = person.getCaregiverId();
        String personName = person.getFullName();

        // Get all push tokens for this caregiver
        List<PushToken> tokens = pushTokenRepository.findByUserId(caregiverId);
        if (tokens.isEmpty()) {
            log.debug("[FCM] No push tokens for caregiver={} — alert={} available via polling",
                    caregiverId, alertId);
            return;
        }

        int confidencePercent = (int) Math.round(confidence * 100);

        for (PushToken token : tokens) {
            FallAlertPushMessages.Content notification =
                    FallAlertPushMessages.forLocale(token.getLocale(), personName, confidencePercent);

            try {
                Message message = Message.builder()
                        .setToken(token.getFcmToken())
                        .setNotification(Notification.builder()
                                .setTitle(notification.title())
                                .setBody(notification.body())
                                .build())
                        // Data payload for app navigation
                        .putData("type", "FALL_ALERT")
                        .putData("alertId", alertId.toString())
                        .putData("monitoredPersonId", monitoredPersonId.toString())
                        .putData("personName", personName)
                        .putData("confidence", String.valueOf(confidence))
                        .putData("recipientUserId", caregiverId.toString())
                        .build();

                String messageId = FirebaseMessaging.getInstance().send(message);
                log.info("[FCM] Push sent to caregiver={} device={} messageId={}",
                        caregiverId, token.getDeviceId(), messageId);

            } catch (FirebaseMessagingException e) {
                handleFcmError(token, e);
            } catch (Exception e) {
                log.error("[FCM] Unexpected error sending push to device={}: {}",
                        token.getDeviceId(), e.getMessage());
            }
        }
    }

    /**
     * Handles FCM errors. If the token is invalid/unregistered,
     * removes it from the database to avoid future failures.
     */
    private void handleFcmError(PushToken token, FirebaseMessagingException e) {
        MessagingErrorCode code = e.getMessagingErrorCode();

        if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
            log.warn("[FCM] Token invalid/unregistered — removing device={} user={}",
                    token.getDeviceId(), token.getUserId());
            pushTokenRepository.delete(token);
        } else {
            log.error("[FCM] Error sending to device={}: code={} msg={}",
                    token.getDeviceId(), code, e.getMessage());
        }
    }
}
