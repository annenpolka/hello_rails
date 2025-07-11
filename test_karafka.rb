#!/usr/bin/env ruby

# Test script to check Karafka setup
require_relative 'config/environment'

puts "Testing Karafka setup..."

# Send a test message to the example topic
begin
  Karafka.producer.produce_sync(
    topic: 'example',
    payload: { 'message' => 'Hello Karafka!', 'timestamp' => Time.now.to_s }.to_json
  )
  puts "✅ Test message sent successfully to 'example' topic"
rescue => e
  puts "❌ Error sending message: #{e.message}"
  puts e.backtrace
end

# Check if we can create a topic
begin
  puts "\nKarafka configuration:"
  puts "- Client ID: #{KarafkaApp.config.client_id}"
  puts "- Group ID: #{KarafkaApp.config.group_id}"
  puts "- Bootstrap servers: #{KarafkaApp.config.kafka['bootstrap.servers']}"
rescue => e
  puts "❌ Error checking configuration: #{e.message}"
end

puts "\nTest completed!"