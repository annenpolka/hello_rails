class FriendActivitiesConsumer < ApplicationConsumer
  # friend_activities トピックからフレンドアクティビティを処理
  # key = user_id でパーティション分散されたメッセージを処理
  
  def consume
    messages.each do |message|
      begin
        user_id = message.key&.to_i
        next unless user_id
        
        # payloadの型チェックとパース
        payload = case message.payload
                  when String
                    JSON.parse(message.payload)
                  when Hash
                    message.payload
                  else
                    message.payload.to_h
                  end
        
        puts "=" * 60
        puts "🎮 FRIEND ACTIVITY RECEIVED"
        puts "   ユーザーID: #{user_id}"
        puts "   アクティビティ: #{payload['activity_type']}"
        puts "   メッセージ: #{payload['message']}"
        puts "   送信者: #{payload['from_user']&.[]('email') || 'システム'}"
        puts "   Kafka Partition: #{message.partition}"
        puts "   時刻: #{Time.current.strftime('%H:%M:%S')}"
        puts "   Payload型: #{message.payload.class}"
        
        # WebSocketで該当ユーザーに通知を送信
        ActionCable.server.broadcast(
          "user_#{user_id}_channel",
          {
            action: 'friend_notification',
            payload: payload,
            kafka_metadata: {
              topic: message.topic,
              partition: message.partition,
              offset: message.offset,
              timestamp: message.timestamp,
              key: message.key
            }
          }
        )
        
        puts "📤 WebSocket配信完了: user_#{user_id}_channel"
        puts "=" * 60
        
      rescue JSON::ParserError => e
        puts "❌ [FRIEND_ACTIVITIES] JSON Parse Error: #{e.message}"
        puts "   Raw payload: #{message.payload.inspect}"
      rescue => e
        puts "❌ [FRIEND_ACTIVITIES] Processing Error: #{e.message}"
        puts "   Key: #{message.key}, Payload length: #{message.payload.length}"
      end
    end
  end
end