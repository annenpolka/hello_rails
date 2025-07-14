class UserChannel < ApplicationCable::Channel
  def subscribed
    # ユーザーIDを取得
    user_id = params[:user_id]
    
    # テスト環境での認証チェック緩和
    # 開発環境ではテスト用ユーザー切り替えを許可
    if Rails.env.development?
      # 開発環境では指定されたuser_idが有効な場合に接続を許可
      target_user = User.find_by(id: user_id)
      if target_user
        stream_from "user_#{user_id}_channel"
        puts "🔌 Test User #{user_id} (#{target_user.email_address}) subscribed to personal notification channel"
        puts "⚠️ Development mode: Authentication bypassed for testing"
      else
        reject
        puts "❌ Invalid user_id: #{user_id}"
        return
      end
    else
      # 本番環境では通常の認証チェック
      if current_user.is_a?(User) && current_user.id == user_id.to_i
        stream_from "user_#{user_id}_channel"
        puts "🔌 User #{user_id} (#{current_user.email_address}) subscribed to personal notification channel"
      else
        reject
        puts "❌ Unauthorized subscription attempt for user #{user_id} (current_user: #{current_user.class})"
        return
      end
    end
  end

  def unsubscribed
    user_id = params[:user_id]
    puts "🔌 User #{user_id} unsubscribed from personal notification channel"
  end
  
  def send_friend_request(data)
    # 開発環境ではテスト用ユーザーの取得を許可
    acting_user = get_acting_user
    unless acting_user
      transmit_error('ユーザーが見つかりません')
      return
    end
    
    friend_email = data['friend_email']
    
    unless friend_email.present?
      transmit_error('フレンドのメールアドレスが必要です')
      return
    end
    
    friend = User.find_by(email_address: friend_email)
    
    unless friend
      transmit_error('指定されたメールアドレスのユーザーが見つかりません')
      return
    end
    
    if acting_user.friendship_exists_with?(friend)
      transmit_error('既にフレンド関係が存在します')
      return
    end
    
    friendship = acting_user.send_friend_request(friend)
    
    if friendship.persisted?
      transmit({
        action: 'friend_request_sent',
        status: 'success',
        message: "#{friend.email_address}にフレンド申請を送信しました",
        friendship: {
          id: friendship.id,
          friend_email: friend.email_address,
          status: friendship.status
        }
      })
    else
      transmit_error('フレンド申請の送信に失敗しました')
    end
  end
  
  def accept_friend_request(data)
    acting_user = get_acting_user
    unless acting_user
      transmit_error('ユーザーが見つかりません')
      return
    end
    
    friendship_id = data['friendship_id']
    
    unless friendship_id.present?
      transmit_error('フレンドシップIDが必要です')
      return
    end
    
    friendship = acting_user.incoming_friendships.pending.find_by(id: friendship_id)
    
    unless friendship
      transmit_error('指定されたフレンド申請が見つかりません')
      return
    end
    
    friendship.accept!
    
    transmit({
      action: 'friend_request_accepted',
      status: 'success',
      message: "#{friendship.user.email_address}のフレンド申請を承認しました",
      friendship: {
        id: friendship.id,
        friend_email: friendship.user.email_address,
        status: friendship.status
      }
    })
  end
  
  def reject_friend_request(data)
    acting_user = get_acting_user
    unless acting_user
      transmit_error('ユーザーが見つかりません')
      return
    end
    
    friendship_id = data['friendship_id']
    
    unless friendship_id.present?
      transmit_error('フレンドシップIDが必要です')
      return
    end
    
    friendship = acting_user.incoming_friendships.pending.find_by(id: friendship_id)
    
    unless friendship
      transmit_error('指定されたフレンド申請が見つかりません')
      return
    end
    
    friendship.reject!
    
    transmit({
      action: 'friend_request_rejected',
      status: 'success',
      message: "#{friendship.user.email_address}のフレンド申請を拒否しました",
      friendship: {
        id: friendship.id,
        friend_email: friendship.user.email_address,
        status: friendship.status
      }
    })
  end
  
  def send_activity_notification(data)
    acting_user = get_acting_user
    unless acting_user
      transmit_error('ユーザーが見つかりません')
      return
    end
    
    friend_id = data['friend_id']
    activity_type = data['activity_type']
    message = data['message']
    
    unless friend_id.present? && activity_type.present? && message.present?
      transmit_error('friend_id、activity_type、messageが必要です')
      return
    end
    
    friend = User.find_by(id: friend_id)
    
    unless friend && acting_user.friends_with?(friend)
      transmit_error('指定されたユーザーはフレンドではありません')
      return
    end
    
    FriendNotificationService.new.send_activity_notification(
      acting_user, friend, activity_type, message
    )
    
    transmit({
      action: 'activity_notification_sent',
      status: 'success',
      message: "#{friend.email_address}に通知を送信しました"
    })
  end
  
  private
  
  def get_acting_user
    if Rails.env.development?
      # 開発環境ではテスト用ユーザー切り替えをサポート
      user_id = params[:user_id]
      User.find_by(id: user_id)
    else
      # 本番環境では通常の認証チェック
      current_user.is_a?(User) ? current_user : nil
    end
  end
  
  def transmit_error(message)
    transmit({
      action: 'error',
      status: 'error',
      message: message
    })
  end
end