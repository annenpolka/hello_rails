#!/usr/bin/env ruby

# Test script to check if consumer can process messages
require_relative 'config/environment'

puts "Testing consumer setup..."

# Send a test message first
begin
  Karafka.producer.produce_sync(
    topic: 'example',
    payload: { 'message' => 'Test message from consumer test', 'timestamp' => Time.now.to_s }.to_json
  )
  puts "✅ Test message sent to 'example' topic"
rescue => e
  puts "❌ Error sending message: #{e.message}"
  exit 1
end

# Now let's test if we can process messages manually
puts "\nTesting manual message processing..."

# Create a consumer instance
consumer = ExampleConsumer.new

# Check if consumer class is properly set up
puts "Consumer class: #{consumer.class}"
puts "Consumer responds to consume: #{consumer.respond_to?(:consume)}"

puts "\nTo test actual message consumption, run: bundle exec karafka server"
puts "The server will start and consume messages from the 'example' topic"
puts "Press Ctrl+C to stop the server"