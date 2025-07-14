# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# フレンド機能テスト用のサンプルユーザー作成
unless Rails.env.production?
  puts "🌱 フレンド機能テスト用データを作成中..."
  
  # テストユーザー1
  user1 = User.find_or_create_by(email_address: 'alice@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end
  
  # テストユーザー2
  user2 = User.find_or_create_by(email_address: 'bob@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end
  
  # テストユーザー3
  user3 = User.find_or_create_by(email_address: 'charlie@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end
  
  puts "✅ テストユーザー作成完了:"
  puts "   - alice@example.com (ID: #{user1.id})"
  puts "   - bob@example.com (ID: #{user2.id})"
  puts "   - charlie@example.com (ID: #{user3.id})"
  puts "   パスワード: password123"
  
  # サンプルフレンド関係の作成
  unless Friendship.exists?(user: user1, friend: user2)
    friendship = user1.send_friend_request(user2)
    puts "📤 #{user1.email_address} → #{user2.email_address} フレンド申請送信"
  end
  
  unless Friendship.exists?(user: user2, friend: user3)
    friendship = user2.send_friend_request(user3)
    friendship.accept! if friendship
    puts "✅ #{user2.email_address} ↔ #{user3.email_address} フレンド関係確立"
  end
  
  puts "\n🔌 WebSocketテスト手順:"
  puts "1. /kafka/websocket にアクセス"
  puts "2. ユーザーでログイン (/session/new)"
  puts "3. 複数ブラウザタブで異なるユーザーでログイン"
  puts "4. フレンド申請やアクティビティ通知をテスト"
end
