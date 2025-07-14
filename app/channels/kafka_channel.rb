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

    puts "📤 Sending message to Kafka: #{message[:type]}"

    # Kafkaに非同期メッセージ送信
    begin
      Karafka.producer.produce_async(
        topic: 'example',
        payload: message.to_json,
        key: message[:type]
      ) do |delivery_report|
        handle_message_delivery_result(delivery_report, message)
      end
      
      # 非同期送信開始をクライアントに即座に通知
      transmit({
        action: 'message_sent',
        status: 'sending',
        message: message,
        note: '送信中...'
      })
    rescue => e
      puts "❌ Error initiating Kafka send: #{e.message}"
      
      # 送信開始エラーをクライアントに通知
      transmit({
        action: 'message_sent',
        status: 'error',
        error: e.message,
        message: message
      })
    end
  end

  private

  def handle_message_delivery_result(delivery_report, message)
    if delivery_report.error
      puts "❌ Message delivery failed: Error=#{delivery_report.error}"
      
      # 送信失敗をクライアントに通知
      transmit({
        action: 'message_sent',
        status: 'failed',
        error: delivery_report.error.to_s,
        message: message
      })
    else
      puts "✅ Message delivered: Topic=#{delivery_report.topic}, Partition=#{delivery_report.partition}, Offset=#{delivery_report.offset}"
      
      # 送信成功をクライアントに通知
      transmit({
        action: 'message_sent',
        status: 'success',
        message: message,
        kafka_info: {
          topic: delivery_report.topic,
          partition: delivery_report.partition,
          offset: delivery_report.offset
        }
      })
    end
  end
end