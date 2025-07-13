class KafkaChannel < ApplicationCable::Channel
  def subscribed
    stream_from "kafka_messages"
    puts "🔌 Client subscribed to kafka_messages channel"
  end

  def unsubscribed
    puts "🔌 Client unsubscribed from kafka_messages channel"
  end

  def send_message(data)
    message = {
      content: data['content'],
      type: data['type'] || 'user_message',
      timestamp: Time.current.iso8601,
      user: current_user || 'anonymous'
    }

    # Kafkaにメッセージ送信
    begin
      Karafka.producer.produce_sync(
        topic: 'example',
        payload: message.to_json,
        key: message[:type]
      )
      
      puts "📤 Message sent to Kafka: #{message[:type]}"
      
      # 送信成功をクライアントに通知
      transmit({
        action: 'message_sent',
        status: 'success',
        message: message
      })
    rescue => e
      puts "❌ Error sending to Kafka: #{e.message}"
      
      # エラーをクライアントに通知
      transmit({
        action: 'message_sent',
        status: 'error',
        error: e.message
      })
    end
  end
end