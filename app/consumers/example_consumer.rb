# frozen_string_literal: true

# Example consumer that prints messages payloads and broadcasts to WebSocket
class ExampleConsumer < ApplicationConsumer
  private

  # ActionCableサーバーの直接ブロードキャストを使用するため、Redis接続は不要
  def consume
    messages.each do |message|
      # メッセージ処理
      begin
        puts "📨 Payload class: #{message.payload.class}"
        puts "📨 Payload inspect: #{message.payload.inspect}"

        # payloadの型チェックとパース
        parsed_payload = case message.payload
                        when String
                          JSON.parse(message.payload)
                        when Hash
                          message.payload
                        else
                          message.payload.to_h
                        end
        puts "✅ Payload processed (#{message.payload.class}): #{parsed_payload.inspect}"

        puts "📨 RECEIVED FROM KAFKA: #{parsed_payload.inspect}"
        puts "📨 Topic: #{message.topic}, Partition: #{message.partition}, Offset: #{message.offset}"

        # ActionCableでWebSocketクライアントにブロードキャスト
        broadcast_data = {
          "action" => "message_received",
          "payload" => parsed_payload,
          "kafka_metadata" => {
            "topic" => message.topic.to_s,
            "partition" => message.partition.to_s,
            "offset" => message.offset.to_s,
            "timestamp" => message.timestamp.to_s
          }
        }

        puts "📡 Broadcasting: #{broadcast_data.inspect}"

        # ActionCableの標準ブロードキャスト機能を使用（同期）
        puts "📡 Broadcasting via ActionCable.server.broadcast"
        begin
          ActionCable.server.broadcast("kafka_messages", broadcast_data)
          puts "📡 Broadcast successful: #{broadcast_data.inspect}"
        rescue => broadcast_error
          puts "❌ ActionCable broadcast error: #{broadcast_error.message}"
          puts "❌ Error details: #{broadcast_error.class}"
          puts "❌ Backtrace: #{broadcast_error.backtrace&.first(3)}"
        end

      rescue JSON::ParserError => e
        puts "⚠️  Failed to parse JSON: #{e.message}"
        puts "📨 RAW CONTENT (inspect): #{message.payload.inspect}"
      rescue => e
        puts "❌ Error processing message: #{e.message}"
        puts "❌ Backtrace: #{e.backtrace&.first(3)}"
        puts "❌ Message class: #{message.class}"
        puts "❌ Payload class: #{message.payload.class}"
      end
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
