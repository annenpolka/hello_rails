class KafkaController < ApplicationController
  def index
    @messages = session[:kafka_messages] || []
  end

  def send_message
    message_content = params[:message]
    
    if message_content.present?
      begin
        # Send message to Kafka
        Karafka.producer.produce_sync(
          topic: 'example',
          payload: {
            content: message_content,
            timestamp: Time.now.to_s,
            user_id: 'rails_user',
            source: 'web_interface'
          }.to_json
        )
        
        flash[:notice] = "Message sent to Kafka successfully!"
        
        # Store message in session for display (in real app, you'd use a database)
        session[:kafka_messages] ||= []
        session[:kafka_messages] << {
          content: message_content,
          timestamp: Time.now.to_s,
          status: 'sent'
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
end