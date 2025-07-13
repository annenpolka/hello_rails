class KafkaController < ApplicationController
  # CSRF保護をbroadcast_from_consumerアクションのみスキップ
  skip_before_action :verify_authenticity_token, only: [ :broadcast_from_consumer ]
  def index
    @messages = session[:kafka_messages] || []
  end

  def websocket
    # WebSocket接続用のページ
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
end
