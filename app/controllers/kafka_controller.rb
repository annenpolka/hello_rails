class KafkaController < ApplicationController
  # CSRF保護をbroadcast_from_consumerアクションのみスキップ
  skip_before_action :verify_authenticity_token, only: [ :broadcast_from_consumer ]
  # WebSocketページは認証なしでアクセス可能
  allow_unauthenticated_access
  # WebSocketページとデバッグページでセッションを復元
  before_action :restore_session, only: [:websocket, :debug]
  def index
    @messages = session[:kafka_messages] || []
  end

  def websocket
    # WebSocket接続用のページ
  end

  def debug
    # フレンド通知デバッグページ
    @users = User.all
    @current_user = current_user
    @friendships = Friendship.includes(:user, :friend).order(created_at: :desc).limit(20)
  end

  def send_message
    message_content = params[:message]

    if message_content.present?
      begin
        # Send message to Kafka
        Karafka.producer.produce_sync(
          topic: "example",
          payload: {
            content: message_content,
            timestamp: Time.now.to_s,
            user_id: "rails_user",
            source: "web_interface"
          }.to_json
        )

        flash[:notice] = "Message sent to Kafka successfully!"

        # Store message in session for display (in real app, you'd use a database)
        session[:kafka_messages] ||= []
        session[:kafka_messages] << {
          content: message_content,
          timestamp: Time.now.to_s,
          status: "sent"
        }

        # Keep only last 10 messages
        session[:kafka_messages] = session[:kafka_messages].last(10)

      rescue => e
        flash[:alert] = "Error sending message: #{e.message}"
      end
    else
      flash[:alert] = "Message content cannot be empty"
    end

    redirect_to kafka_index_path
  end

  def clear_messages
    session[:kafka_messages] = []
    flash[:notice] = "Message history cleared"
    redirect_to kafka_index_path
  end

  def test_broadcast
    ActionCable.server.broadcast("kafka_messages", {
      action: "message_received",
      payload: { content: "Test broadcast", type: "test" },
      kafka_metadata: { topic: "test", partition: "0", offset: "999" }
    })

    render json: { status: "broadcast sent" }
  end

  def broadcast_from_consumer
    broadcast_data = JSON.parse(request.body.read)

    ActionCable.server.broadcast("kafka_messages", broadcast_data)

    render json: { status: "broadcast executed" }
  end

  def send_test_notification
    user_id = params[:user_id]
    notification_type = params[:notification_type]
    message = params[:message]

    unless user_id.present? && notification_type.present? && message.present?
      flash[:alert] = "すべてのパラメータを入力してください"
      redirect_to kafka_debug_path
      return
    end

    user = User.find_by(id: user_id)
    unless user
      flash[:alert] = "指定されたユーザーが見つかりません"
      redirect_to kafka_debug_path
      return
    end

    begin
      case notification_type
      when 'user_notification'
        notification = {
          type: 'test_notification',
          to_user: { id: user.id, email: user.email_address },
          message: message,
          timestamp: Time.current.iso8601
        }
        
        Karafka.producer.produce_sync(
          topic: 'user_notifications',
          key: user.id.to_s,
          payload: notification.to_json
        )
        
      when 'friend_activity'
        notification = {
          type: 'friend_activity',
          activity_type: 'test_activity',
          to_user: { id: user.id, email: user.email_address },
          from_user: { id: current_user&.id || 0, email: current_user&.email_address || 'system' },
          message: message,
          timestamp: Time.current.iso8601
        }
        
        Karafka.producer.produce_sync(
          topic: 'friend_activities',
          key: user.id.to_s,
          payload: notification.to_json
        )
      end

      flash[:notice] = "#{user.email_address}にテスト通知を送信しました"
    rescue => e
      flash[:alert] = "通知送信エラー: #{e.message}"
    end

    redirect_to kafka_debug_path
  end

  def send_friend_request
    from_user_id = params[:from_user_id]
    to_user_id = params[:to_user_id]

    unless from_user_id.present? && to_user_id.present?
      flash[:alert] = "送信者と受信者を選択してください"
      redirect_to kafka_debug_path
      return
    end

    from_user = User.find_by(id: from_user_id)
    to_user = User.find_by(id: to_user_id)

    unless from_user && to_user
      flash[:alert] = "指定されたユーザーが見つかりません"
      redirect_to kafka_debug_path
      return
    end

    if from_user == to_user
      flash[:alert] = "自分自身にフレンド申請はできません"
      redirect_to kafka_debug_path
      return
    end

    if from_user.friendship_exists_with?(to_user)
      flash[:alert] = "既にフレンド関係が存在します"
      redirect_to kafka_debug_path
      return
    end

    begin
      friendship = from_user.send_friend_request(to_user)
      if friendship&.persisted?
        flash[:notice] = "#{from_user.email_address} → #{to_user.email_address} にフレンド申請を送信しました"
      else
        flash[:alert] = "フレンド申請の送信に失敗しました"
      end
    rescue => e
      flash[:alert] = "エラー: #{e.message}"
    end

    redirect_to kafka_debug_path
  end

  def accept_friend_request
    friendship_id = params[:friendship_id]

    unless friendship_id.present?
      flash[:alert] = "フレンドシップIDが必要です"
      redirect_to kafka_debug_path
      return
    end

    friendship = Friendship.find_by(id: friendship_id)
    unless friendship
      flash[:alert] = "指定されたフレンド申請が見つかりません"
      redirect_to kafka_debug_path
      return
    end

    if friendship.status != 'pending'
      flash[:alert] = "この申請は既に処理済みです"
      redirect_to kafka_debug_path
      return
    end

    begin
      friendship.accept!
      flash[:notice] = "#{friendship.user.email_address} → #{friendship.friend.email_address} のフレンド申請を承認しました"
    rescue => e
      flash[:alert] = "承認エラー: #{e.message}"
    end

    redirect_to kafka_debug_path
  end

  def delete_all_friendships
    begin
      deleted_count = Friendship.count
      Friendship.delete_all
      flash[:notice] = "全フレンド関係を削除しました (#{deleted_count}件)"
    rescue => e
      flash[:alert] = "削除エラー: #{e.message}"
    end

    redirect_to kafka_debug_path
  end

  private

  def restore_session
    # セッションを手動で復元してcurrent_userを利用可能にする
    Current.session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end
end
