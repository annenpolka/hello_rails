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
    puts "📤 Sending user notification to user_notifications[#{user_id}]: #{notification[:type]}"
    
    Karafka.producer.produce_async(
      topic: 'user_notifications',
      key: user_id.to_s,  # パーティション分散キー
      payload: notification.to_json
    ) do |delivery_report|
      handle_user_notification_result(delivery_report, user_id, notification)
    end
  rescue => e
    puts "❌ Error initiating user notification send: #{e.message}"
    Rails.logger.error "User notification send error: #{e.message}"
    handle_failed_notification(user_id, notification, 'user_notification', e.message)
  end
  
  def send_friend_activity(user_id, notification)
    puts "📤 Sending friend activity to friend_activities[#{user_id}]: #{notification[:activity_type]}"
    
    Karafka.producer.produce_async(
      topic: 'friend_activities',
      key: user_id.to_s,  # パーティション分散キー
      payload: notification.to_json
    ) do |delivery_report|
      handle_friend_activity_result(delivery_report, user_id, notification)
    end
  rescue => e
    puts "❌ Error initiating friend activity send: #{e.message}"
    Rails.logger.error "Friend activity send error: #{e.message}"
    handle_failed_notification(user_id, notification, 'friend_activity', e.message)
  end

  # 非同期送信結果のハンドリング
  def handle_user_notification_result(delivery_report, user_id, notification)
    if delivery_report.error
      puts "❌ User notification delivery failed: User=#{user_id}, Error=#{delivery_report.error}"
      Rails.logger.error "User notification delivery failed: User=#{user_id}, Error=#{delivery_report.error}"
      
      # WebSocketでエラー通知
      broadcast_error_to_user(user_id, "通知送信に失敗しました: #{delivery_report.error}")
      
      # 失敗した通知の保存・リトライ処理
      handle_failed_notification(user_id, notification, 'user_notification', delivery_report.error.to_s)
    else
      puts "✅ User notification delivered: User=#{user_id}, Topic=#{delivery_report.topic}, Partition=#{delivery_report.partition}, Offset=#{delivery_report.offset}"
      Rails.logger.info "User notification delivered: User=#{user_id}, Offset=#{delivery_report.offset}"
      
      # 成功統計の更新
      update_notification_stats(user_id, 'user_notification', :success)
    end
  end

  def handle_friend_activity_result(delivery_report, user_id, notification)
    if delivery_report.error
      puts "❌ Friend activity delivery failed: User=#{user_id}, Error=#{delivery_report.error}"
      Rails.logger.error "Friend activity delivery failed: User=#{user_id}, Error=#{delivery_report.error}"
      
      # WebSocketでエラー通知
      broadcast_error_to_user(user_id, "フレンドアクティビティ通知送信に失敗しました: #{delivery_report.error}")
      
      # 失敗した通知の保存・リトライ処理
      handle_failed_notification(user_id, notification, 'friend_activity', delivery_report.error.to_s)
    else
      puts "✅ Friend activity delivered: User=#{user_id}, Topic=#{delivery_report.topic}, Partition=#{delivery_report.partition}, Offset=#{delivery_report.offset}"
      Rails.logger.info "Friend activity delivered: User=#{user_id}, Offset=#{delivery_report.offset}"
      
      # 成功統計の更新
      update_notification_stats(user_id, 'friend_activity', :success)
    end
  end

  # エラー時のWebSocket通知
  def broadcast_error_to_user(user_id, error_message)
    begin
      ActionCable.server.broadcast("user_#{user_id}_channel", {
        action: 'notification_error',
        message: error_message,
        timestamp: Time.current.iso8601
      })
    rescue => e
      Rails.logger.error "Failed to broadcast error to user #{user_id}: #{e.message}"
    end
  end

  # 失敗した通知の処理
  def handle_failed_notification(user_id, notification, notification_type, error_message)
    begin
      # 開発環境ではログ出力のみ
      if Rails.env.development?
        puts "🗄️ Failed notification logged: User=#{user_id}, Type=#{notification_type}, Error=#{error_message}"
        Rails.logger.warn "Failed notification: User=#{user_id}, Type=#{notification_type}, Payload=#{notification}, Error=#{error_message}"
      else
        # 本番環境では失敗したメッセージをデータベースに保存してリトライキューに追加
        # FailedNotification.create!(
        #   user_id: user_id,
        #   notification_type: notification_type,
        #   payload: notification.to_json,
        #   error_message: error_message,
        #   retry_count: 0,
        #   next_retry_at: 5.minutes.from_now
        # )
      end
    rescue => e
      Rails.logger.error "Failed to handle failed notification: #{e.message}"
    end
  end

  # 通知統計の更新
  def update_notification_stats(user_id, notification_type, status)
    begin
      # 開発環境では簡単なログ出力
      if Rails.env.development?
        puts "📊 Notification stats: User=#{user_id}, Type=#{notification_type}, Status=#{status}"
      else
        # 本番環境では統計テーブルに記録
        # NotificationStats.increment_counter(notification_type, status, user_id)
      end
    rescue => e
      Rails.logger.error "Failed to update notification stats: #{e.message}"
    end
  end
end