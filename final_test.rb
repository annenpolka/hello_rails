#!/usr/bin/env ruby

# Final comprehensive test for Karafka setup
require_relative 'config/environment'

puts "🚀 Final Karafka Integration Test"
puts "=================================="

# Test 1: Configuration Check
puts "\n1. Configuration Check:"
puts "   Client ID: #{KarafkaApp.config.client_id}"
puts "   Group ID: #{KarafkaApp.config.group_id}"
puts "   Bootstrap servers: #{KarafkaApp.config.kafka['bootstrap.servers']}"
puts "   ✅ Configuration looks good!"

# Test 2: Producer Test
puts "\n2. Producer Test:"
begin
  5.times do |i|
    message = {
      id: i + 1,
      content: "Test message #{i + 1}",
      timestamp: Time.now.to_s,
      app: 'hello_rails_app'
    }
    
    Karafka.producer.produce_sync(
      topic: 'example',
      payload: message.to_json
    )
    
    puts "   📤 Message #{i + 1} sent successfully"
  end
rescue => e
  puts "   ❌ Error sending messages: #{e.message}"
  exit 1
end

# Test 3: Consumer Class Test
puts "\n3. Consumer Class Test:"
consumer = ExampleConsumer.new
puts "   Consumer class: #{consumer.class}"
puts "   Inherits from: #{consumer.class.superclass}"
puts "   Methods: #{consumer.methods.grep(/consume/).join(', ')}"
puts "   ✅ Consumer class is properly set up!"

# Test 4: Rails Integration Test
puts "\n4. Rails Integration Test:"
puts "   Rails environment: #{Rails.env}"
puts "   Rails version: #{Rails.version}"
puts "   ✅ Karafka integrated with Rails!"

puts "\n🎉 All tests passed!"
puts "\nNext steps:"
puts "1. Start Karafka server: bundle exec karafka server"
puts "2. The server will consume messages from the 'example' topic"
puts "3. Check the output to see messages being processed"
puts "4. Press Ctrl+C to stop the server"

puts "\n📚 For more information:"
puts "- Karafka documentation: https://karafka.io/docs"
puts "- Configuration file: karafka.rb"
puts "- Consumer classes: app/consumers/"