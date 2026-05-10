package com.visualpathit.account.service;

import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;
import com.visualpathit.account.utils.RabbitMqUtil;

import org.springframework.stereotype.Service;
import com.rabbitmq.client.Channel;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

@Service
public class ProducerServiceImpl implements ProducerService {

    /**
     * The name of the Exchange
     */
    private static final String EXCHANGE_NAME = "messages";

    /**
     * This method publishes a message
     * @param message
     */
    @Override
    public String produceMessage(String message) {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost(RabbitMqUtil.getRabbitMqHost());
        factory.setPort(Integer.parseInt(RabbitMqUtil.getRabbitMqPort()));
        factory.setUsername(RabbitMqUtil.getRabbitMqUser());
        factory.setPassword(RabbitMqUtil.getRabbitMqPassword());

        // try-with-resources ensures both Connection and Channel are always
        // closed on exit, even if an exception is thrown mid-way
        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {

            System.out.println("Connection open status: " + connection.isOpen());
            channel.exchangeDeclare(EXCHANGE_NAME, "fanout");
            channel.basicPublish(EXCHANGE_NAME, "", null, message.getBytes());
            System.out.println(" [x] Sent '" + message + "'");

        } catch (IOException io) {
            System.out.println("IOException");
            io.printStackTrace();
        } catch (TimeoutException toe) {
            System.out.println("TimeoutException : " + toe.getMessage());
            toe.printStackTrace();
        }
        return "response";
    }
}