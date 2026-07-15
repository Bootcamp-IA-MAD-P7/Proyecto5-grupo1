package com.sentilife.notifications;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * RabbitMQ configuration for the caregiver notification pipeline (RF-30).
 *
 * Exchange: sentilife.alerts (topic)
 * Queue:    sentilife.alerts.push
 * Routing:  alert.created | monitoring.started | monitoring.stopped | consent.revoked
 */
@Configuration
@ConditionalOnProperty(name = "spring.rabbitmq.listener.simple.auto-startup", havingValue = "true", matchIfMissing = true)
public class RabbitConfig {

    public static final String ALERTS_EXCHANGE = "sentilife.alerts";
    public static final String PUSH_QUEUE = "sentilife.alerts.push";
    public static final String ROUTING_KEY_ALERT_CREATED = "alert.created";
    public static final String ROUTING_KEY_MONITORING_STARTED = "monitoring.started";
    public static final String ROUTING_KEY_MONITORING_STOPPED = "monitoring.stopped";
    public static final String ROUTING_KEY_CONSENT_REVOKED = "consent.revoked";

    /** @deprecated use {@link #ROUTING_KEY_ALERT_CREATED} */
    @Deprecated
    public static final String ROUTING_KEY = ROUTING_KEY_ALERT_CREATED;

    @Bean
    public TopicExchange alertsExchange() {
        return new TopicExchange(ALERTS_EXCHANGE, true, false);
    }

    @Bean
    public Queue pushQueue() {
        return QueueBuilder.durable(PUSH_QUEUE).build();
    }

    @Bean
    public Binding alertCreatedBinding(Queue pushQueue, TopicExchange alertsExchange) {
        return BindingBuilder.bind(pushQueue).to(alertsExchange).with(ROUTING_KEY_ALERT_CREATED);
    }

    @Bean
    public Binding monitoringStartedBinding(Queue pushQueue, TopicExchange alertsExchange) {
        return BindingBuilder.bind(pushQueue).to(alertsExchange).with(ROUTING_KEY_MONITORING_STARTED);
    }

    @Bean
    public Binding monitoringStoppedBinding(Queue pushQueue, TopicExchange alertsExchange) {
        return BindingBuilder.bind(pushQueue).to(alertsExchange).with(ROUTING_KEY_MONITORING_STOPPED);
    }

    @Bean
    public Binding consentRevokedBinding(Queue pushQueue, TopicExchange alertsExchange) {
        return BindingBuilder.bind(pushQueue).to(alertsExchange).with(ROUTING_KEY_CONSENT_REVOKED);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}
