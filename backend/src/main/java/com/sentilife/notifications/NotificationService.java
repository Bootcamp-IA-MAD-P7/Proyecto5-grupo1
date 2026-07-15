package com.sentilife.notifications;

import com.google.firebase.messaging.AndroidConfig;
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
 * Fall alerts use high priority; monitoring/consent status uses normal priority (RF-30).
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

    public void sendFallAlert(UUID monitoredPersonId, UUID alertId, double confidence) {
        if (!firebaseConfig.isInitialized()) {
            log.debug("[FCM] Firebase not initialized — skipping push for alert={}", alertId);
            return;
        }

        CaregiverContext ctx = resolveCaregiverContext(monitoredPersonId);
        if (ctx == null) return;

        int confidencePercent = (int) Math.round(confidence * 100);

        for (PushToken token : ctx.tokens()) {
            FallAlertPushMessages.Content notification =
                    FallAlertPushMessages.forLocale(token.getLocale(), ctx.personName(), confidencePercent);

            try {
                Message message = Message.builder()
                        .setToken(token.getFcmToken())
                        .setNotification(Notification.builder()
                                .setTitle(notification.title())
                                .setBody(notification.body())
                                .build())
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.HIGH)
                                .build())
                        .putData("type", CaregiverNotificationEvent.TYPE_FALL_ALERT)
                        .putData("alertId", alertId.toString())
                        .putData("monitoredPersonId", monitoredPersonId.toString())
                        .putData("personName", ctx.personName())
                        .putData("confidence", String.valueOf(confidence))
                        .putData("recipientUserId", ctx.caregiverId().toString())
                        .build();

                String messageId = FirebaseMessaging.getInstance().send(message);
                log.info("[FCM] Fall alert push sent caregiver={} device={} messageId={}",
                        ctx.caregiverId(), token.getDeviceId(), messageId);

            } catch (FirebaseMessagingException e) {
                handleFcmError(token, e);
            } catch (Exception e) {
                log.error("[FCM] Unexpected error sending fall push to device={}: {}",
                        token.getDeviceId(), e.getMessage());
            }
        }
    }

    /**
     * Low-priority status notification for monitoring/consent changes (RF-30).
     */
    public void sendStatusNotification(String type, UUID monitoredPersonId) {
        if (!firebaseConfig.isInitialized()) {
            log.debug("[FCM] Firebase not initialized — skipping status {} person={}",
                    type, monitoredPersonId);
            return;
        }

        CaregiverContext ctx = resolveCaregiverContext(monitoredPersonId);
        if (ctx == null) return;

        for (PushToken token : ctx.tokens()) {
            StatusPushMessages.Content notification =
                    StatusPushMessages.forType(type, token.getLocale(), ctx.personName());

            try {
                Message message = Message.builder()
                        .setToken(token.getFcmToken())
                        .setNotification(Notification.builder()
                                .setTitle(notification.title())
                                .setBody(notification.body())
                                .build())
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.NORMAL)
                                .build())
                        .putData("type", type)
                        .putData("monitoredPersonId", monitoredPersonId.toString())
                        .putData("personName", ctx.personName())
                        .putData("recipientUserId", ctx.caregiverId().toString())
                        .build();

                String messageId = FirebaseMessaging.getInstance().send(message);
                log.info("[FCM] Status push {} sent caregiver={} device={} messageId={}",
                        type, ctx.caregiverId(), token.getDeviceId(), messageId);

            } catch (FirebaseMessagingException e) {
                handleFcmError(token, e);
            } catch (Exception e) {
                log.error("[FCM] Unexpected error sending status push to device={}: {}",
                        token.getDeviceId(), e.getMessage());
            }
        }
    }

    private CaregiverContext resolveCaregiverContext(UUID monitoredPersonId) {
        MonitoredPerson person = monitoredPersonRepository.findById(monitoredPersonId)
                .orElse(null);
        if (person == null) {
            log.warn("[FCM] Monitored person not found: {}", monitoredPersonId);
            return null;
        }

        UUID caregiverId = person.getCaregiverId();
        List<PushToken> tokens = pushTokenRepository.findByUserId(caregiverId);
        if (tokens.isEmpty()) {
            log.debug("[FCM] No push tokens for caregiver={} — person={} available via polling",
                    caregiverId, monitoredPersonId);
            return null;
        }

        return new CaregiverContext(caregiverId, person.getFullName(), tokens);
    }

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

    private record CaregiverContext(UUID caregiverId, String personName, List<PushToken> tokens) {}
}
