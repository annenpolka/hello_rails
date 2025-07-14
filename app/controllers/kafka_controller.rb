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
        # Send message to Kafka asynchronously
        Karafka.producer.produce_async(
          topic: "example",
          payload: {
            content: message_content,
            timestamp: Time.now.to_s,
            user_id: "rails_user",
            source: "web_interface"
          }.to_json
        ) do |delivery_report|
          handle_kafka_delivery_result(delivery_report, message_content)
        end

        flash[:notice] = "Message queued for Kafka delivery!"

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
    repeat_count = params[:repeat_count].to_i
    delay_ms = params[:delay_ms].to_i

    unless user_id.present? && notification_type.present? && message.present?
      flash[:alert] = "すべてのパラメータを入力してください"
      redirect_to kafka_debug_path(
        user_id: user_id,
        notification_type: notification_type,
        message: message,
        repeat_count: repeat_count,
        delay_ms: delay_ms
      )
      return
    end

    # 繰り返し回数の検証
    repeat_count = 1 if repeat_count < 1
    delay_ms = 0 if delay_ms < 0

    user = User.find_by(id: user_id)
    unless user
      flash[:alert] = "指定されたユーザーが見つかりません"
      redirect_to kafka_debug_path(
        user_id: user_id,
        notification_type: notification_type,
        message: message,
        repeat_count: repeat_count,
        delay_ms: delay_ms
      )
      return
    end

    begin
      # 繰り返し送信を別スレッドで実行（非ブロッキング）
      Thread.new do
        repeat_count.times do |i|
          sequence_num = i + 1
          
          case notification_type
          when 'user_notification'
            notification = {
              type: 'test_notification',
              to_user: { id: user.id, email: user.email_address },
              message: repeat_count > 1 ? "#{message} (##{sequence_num}/#{repeat_count})" : message,
              timestamp: Time.current.iso8601,
              sequence: sequence_num,
              total: repeat_count
            }
            
            Karafka.producer.produce_async(
              topic: 'user_notifications',
              key: user.id.to_s,
              payload: notification.to_json
            ) do |delivery_report|
              handle_test_notification_result(delivery_report, user, 'user_notification', sequence_num, repeat_count)
            end
            
          when 'friend_activity'
            notification = {
              type: 'friend_activity',
              activity_type: 'test_activity',
              to_user: { id: user.id, email: user.email_address },
              from_user: { id: current_user&.id || 0, email: current_user&.email_address || 'system' },
              message: repeat_count > 1 ? "#{message} (##{sequence_num}/#{repeat_count})" : message,
              timestamp: Time.current.iso8601,
              sequence: sequence_num,
              total: repeat_count
            }
            
            Karafka.producer.produce_async(
              topic: 'friend_activities',
              key: user.id.to_s,
              payload: notification.to_json
            ) do |delivery_report|
              handle_test_notification_result(delivery_report, user, 'friend_activity', sequence_num, repeat_count)
            end
          end
          
          # 最後以外は遅延を入れる
          if sequence_num < repeat_count && delay_ms > 0
            sleep(delay_ms / 1000.0)
          end
        end
      end

      if repeat_count > 1
        flash[:notice] = "#{user.email_address}に#{repeat_count}回のテスト通知をキューに追加しました（間隔: #{delay_ms}ms）"
      else
        flash[:notice] = "#{user.email_address}にテスト通知をキューに追加しました"
      end
    rescue => e
      flash[:alert] = "通知送信エラー: #{e.message}"
    end

    redirect_to kafka_debug_path(
      user_id: user_id,
      notification_type: notification_type,
      message: message,
      repeat_count: repeat_count,
      delay_ms: delay_ms
    )
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

  def handle_kafka_delivery_result(delivery_report, message_content)
    if delivery_report.error
      Rails.logger.error "Kafka message delivery failed: Error=#{delivery_report.error}, Content=#{message_content}"
      puts "❌ Kafka message delivery failed: #{delivery_report.error}"
    else
      Rails.logger.info "Kafka message delivered: Topic=#{delivery_report.topic}, Offset=#{delivery_report.offset}, Content=#{message_content}"
      puts "✅ Kafka message delivered: Topic=#{delivery_report.topic}, Offset=#{delivery_report.offset}"
    end
  end

  def handle_test_notification_result(delivery_report, user, notification_type, sequence = nil, total = nil)
    sequence_info = sequence && total ? " (#{sequence}/#{total})" : ""
    
    if delivery_report.error
      Rails.logger.error "Test notification delivery failed: User=#{user.email_address}, Type=#{notification_type}#{sequence_info}, Error=#{delivery_report.error}"
      puts "❌ Test notification delivery failed: User=#{user.email_address}#{sequence_info}, Error=#{delivery_report.error}"
    else
      Rails.logger.info "Test notification delivered: User=#{user.email_address}, Type=#{notification_type}#{sequence_info}, Offset=#{delivery_report.offset}"
      puts "✅ Test notification delivered: User=#{user.email_address}#{sequence_info}, Offset=#{delivery_report.offset}"
    end
  end

  def restore_session
    # セッションを手動で復元してcurrent_userを利用可能にする
    Current.session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end
end
