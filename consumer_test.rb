#!/usr/bin/env ruby

# Consumer test script - sends messages and shows how to test consumer
require_relative 'config/environment'

puts "🧪 Consumer Test Script"
puts "======================="

# Send test messages first
puts "\n1. Sending test messages to 'example' topic..."
test_messages = [
  { type: 'user_signup', user_id: 123, email: 'test@example.com' },
  { type: 'order_created', order_id: 456, amount: 99.99 },
  { type: 'payment_processed', payment_id: 789, status: 'success' },
  { type: 'notification_sent', user_id: 123, channel: 'email' }
]

test_messages.each_with_index do |message, index|
  begin
    Karafka.producer.produce_sync(
      topic: 'example',
      payload: message.to_json,
      key: message[:type] # Optional: use message type as key
    )
    puts "   📤 Message #{index + 1} sent: #{message[:type]}"
  rescue => e
    puts "   ❌ Error sending message #{index + 1}: #{e.message}"
  end
end

puts "\n2. Messages sent successfully!"
puts "\n3. To test the consumer, run the following in a separate terminal:"
puts "   cd #{Dir.pwd}"
puts "   bundle exec karafka server"
puts "\n4. You should see the consumer processing these messages:"
puts "   - The ExampleConsumer will print each message payload"
puts "   - Check the terminal running 'karafka server' for output"

puts "\n5. To stop the consumer, press Ctrl+C in the karafka server terminal"

puts "\n📊 Expected output in karafka server terminal:"
test_messages.each do |message|
  puts "   #{message.to_json}"
end

puts "\n🔧 Consumer code location: app/consumers/example_consumer.rb"
puts "📝 You can modify the consumer to add custom processing logic"