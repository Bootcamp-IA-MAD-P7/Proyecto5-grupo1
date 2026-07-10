package com.sentilife.notifications;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * RabbitMQ configuration for the alert notification pipeline.
 *
 * Exchange: sentilife.alerts (topic)
 * Queue:    sentilife.alerts.push
 * Routing:  alert.created → push queue
 *
 * Per ADR-02: RabbitMQ is used only for alert.created → push notifier.
 * The prediction critical path remains synchronous HTTP.
 */
@Configuration
public class RabbitConfig {

    public static final String ALERTS_EXCHANGE = "sentilife.alerts";
    public static final String PUSH_QUEUE = "sentilife.alerts.push";
    public static final String ROUTING_KEY = "alert.created";

    @Bean
    public TopicExchange alertsExchange() {
        return new TopicExchange(ALERTS_EXCHANGE, true, false);
    }

    @Bean
    public Queue pushQueue() {
        return QueueBuilder.durable(PUSH_QUEUE).build();
    }

    @Bean
    public Binding pushBinding(Queue pushQueue, TopicExchange alertsExchange) {
        return BindingBuilder.bind(pushQueue).to(alertsExchange).with(ROUTING_KEY);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}
