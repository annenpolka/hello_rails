class FriendNotificationService
  def self.send_friend_request_notification(friendship)
    new.send_friend_request_notification(friendship)
  end
  
  def self.send_friend_accepted_notification(friendship)
    new.send_friend_accepted_notification(friendship)
  end
  
  def send_friend_request_notification(friendship)
    notification = {
      type: 'friend_request',
      from_user: {
        id: friendship.user.id,
        email: friendship.user.email_address
      },
      to_user: {
        id: friendship.friend.id,
        email: friendship.friend.email_address
      },
      message: "#{friendship.user.email_address}さんからフレンド申請が届きました",
      timestamp: Time.current.iso8601,
      friendship_id: friendship.id
    }
    
    send_user_notification(friendship.friend.id, notification)
  end
  
  def send_friend_accepted_notification(friendship)
    notification = {
      type: 'friend_accepted',
      from_user: {
        id: friendship.friend.id,
        email: friendship.friend.email_address
      },
      to_user: {
        id: friendship.user.id,
        email: friendship.user.email_address
      },
      message: "#{friendship.friend.email_address}さんがフレンド申請を承認しました",
      timestamp: Time.current.iso8601,
      friendship_id: friendship.id
    }
    
    send_user_notification(friendship.user.id, notification)
  end
  
  def send_activity_notification(from_user, to_user, activity_type, message)
    notification = {
      type: 'friend_activity',
      activity_type: activity_type,
      from_user: {
        id: from_user.id,
        email: from_user.email_address
      },
      to_user: {
        id: to_user.id,
        email: to_user.email_address
      },
      message: message,
      timestamp: Time.current.iso8601
    }
    
    send_friend_activity(to_user.id, notification)
  end
  
  private
  
  def send_user_notification(user_id, notification)
    begin
      Karafka.producer.produce_sync(
        topic: 'user_notifications',
        key: user_id.to_s,  # パーティション分散キー
        payload: notification.to_json
      )
      
      puts "📤 User notification sent to user_notifications[#{user_id}]: #{notification[:type]}"
    rescue => e
      puts "❌ Error sending user notification to Kafka: #{e.message}"
      Rails.logger.error "User notification error: #{e.message}"
    end
  end
  
  def send_friend_activity(user_id, notification)
    begin
      Karafka.producer.produce_sync(
        topic: 'friend_activities',
        key: user_id.to_s,  # パーティション分散キー
        payload: notification.to_json
      )
      
      puts "📤 Friend activity sent to friend_activities[#{user_id}]: #{notification[:activity_type]}"
    rescue => e
      puts "❌ Error sending friend activity to Kafka: #{e.message}"
      Rails.logger.error "Friend activity error: #{e.message}"
    end
  end
end