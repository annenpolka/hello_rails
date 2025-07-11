# Karafka テスト・運用ガイド

## 📋 目次
1. [環境セットアップ](#環境セットアップ)
2. [基本テスト](#基本テスト)
3. [Consumer テスト](#consumer-テスト)
4. [Producer テスト](#producer-テスト)
5. [統合テスト](#統合テスト)
6. [トラブルシューティング](#トラブルシューティング)
7. [運用コマンド](#運用コマンド)

---

## 🚀 環境セットアップ

### 1. Kafka/Zookeeper の起動
```bash
# Docker Compose でKafka環境を起動
docker-compose up -d

# コンテナ状態確認
docker ps
```

### 2. Kafka接続確認
```bash
# 基本設定テスト
ruby final_test.rb
```

---

## 🧪 基本テスト

### 設定ファイル確認
- **メイン設定**: `karafka.rb`
- **Consumer基底クラス**: `app/consumers/application_consumer.rb`
- **サンプルConsumer**: `app/consumers/example_consumer.rb`

### 設定値確認
```ruby
# Rails console で確認
rails console
> KarafkaApp.config.client_id
> KarafkaApp.config.group_id
> KarafkaApp.config.kafka['bootstrap.servers']
```

---

## 🎯 Consumer テスト

### 1. Consumer 単体テスト

#### テスト用メッセージ送信
```bash
# テストメッセージを送信
ruby consumer_test.rb
```

#### Consumer 起動・動作確認
```bash
# 別ターミナルで Consumer サーバー起動
bundle exec karafka server

# 期待される出力例:
# {"type":"user_signup","user_id":123,"email":"test@example.com"}
# {"type":"order_created","order_id":456,"amount":99.99"}
# {"type":"payment_processed","payment_id":789,"status":"success"}
# {"type":"notification_sent","user_id":123,"channel":"email"}
```

### 2. Consumer カスタマイズテスト

#### ExampleConsumer の変更例
```ruby
# app/consumers/example_consumer.rb
class ExampleConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      puts "📨 Received: #{message.payload}"
      
      # JSON パース
      data = JSON.parse(message.payload)
      puts "🔍 Message type: #{data['type']}"
      
      # カスタム処理
      case data['type']
      when 'user_signup'
        puts "👤 New user: #{data['email']}"
      when 'order_created'
        puts "🛒 New order: $#{data['amount']}"
      when 'payment_processed'
        puts "💳 Payment: #{data['status']}"
      end
    rescue JSON::ParserError => e
      puts "❌ JSON Parse error: #{e.message}"
    end
  end
end
```

---

## 📤 Producer テスト

### 1. コマンドラインからの送信
```bash
# 基本的なメッセージ送信
ruby -e "
require_relative 'config/environment'
Karafka.producer.produce_sync(
  topic: 'example',
  payload: {message: 'Hello Karafka!', timestamp: Time.now}.to_json
)
puts 'Message sent!'
"
```

### 2. Rails Console からの送信
```ruby
# Rails Console で実行
rails console

# シンプルなメッセージ送信
Karafka.producer.produce_sync(
  topic: 'example',
  payload: 'Hello from Rails console!'
)

# JSONメッセージ送信
Karafka.producer.produce_sync(
  topic: 'example',
  payload: {
    event: 'test',
    data: { user_id: 123, action: 'login' },
    timestamp: Time.now.to_i
  }.to_json
)
```

### 3. Webインターフェースからの送信
```bash
# Rails サーバー起動
bin/rails server

# ブラウザで http://localhost:3000/kafka にアクセス
# フォームからメッセージ送信をテスト
```

---

## 🔄 統合テスト

### 1. 全体動作確認
```bash
# 1. Kafka環境起動
docker-compose up -d

# 2. Consumer起動（別ターミナル）
bundle exec karafka server

# 3. Producer テスト（別ターミナル）
ruby final_test.rb

# 4. Rails Web UI テスト（別ターミナル）
bin/rails server
# http://localhost:3000/kafka でメッセージ送信
```

### 2. 負荷テスト
```bash
# 大量メッセージ送信テスト
ruby -e "
require_relative 'config/environment'
100.times do |i|
  Karafka.producer.produce_sync(
    topic: 'example',
    payload: {id: i, message: 'Load test #{i}', timestamp: Time.now}.to_json
  )
end
puts 'Load test completed!'
"
```

---

## 🚨 トラブルシューティング

### よくある問題と対処法

#### 1. Kafka接続エラー
```bash
# エラー: Connection refused
# 対処: Kafkaコンテナ状態確認
docker ps
docker-compose logs kafka

# 再起動
docker-compose down
docker-compose up -d
```

#### 2. Consumer が起動しない
```bash
# エラー: Consumer group coordinator not found
# 対処: Kafka完全再起動
docker-compose down
docker volume prune  # 注意: 全データ削除
docker-compose up -d
```

#### 3. メッセージが消費されない
```bash
# Consumer group確認
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Topic確認
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

#### 4. Rails統合エラー
```bash
# Karafka設定確認
rails console
> KarafkaApp.config

# Consumer クラス確認
> ExampleConsumer.new.respond_to?(:consume)
```

---

## 🛠️ 運用コマンド

### Kafka 管理コマンド
```bash
# Topic一覧表示
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Topic詳細表示
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic example

# Consumer Group確認
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group hello_rails_app_consumer

# Topic削除（開発時のみ）
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic example
```

### Karafka 運用コマンド
```bash
# Consumer起動
bundle exec karafka server

# 特定のConsumer Groupのみ起動
bundle exec karafka server --consumer-groups hello_rails_app_consumer

# 特定のTopicのみ処理
bundle exec karafka server --topics example

# デバッグモードで起動
KARAFKA_ENV=development bundle exec karafka server
```

### ログ確認
```bash
# Kafka ログ確認
docker-compose logs kafka
docker-compose logs zookeeper

# Karafka ログ確認（実行中のConsumerログ）
# Consumer起動時のコンソール出力を確認
```

---

## 📝 開発時のベストプラクティス

### 1. 開発フロー
1. Kafka環境起動: `docker-compose up -d`
2. Consumer起動: `bundle exec karafka server`
3. Producer テスト: `ruby consumer_test.rb`
4. Consumer動作確認
5. コード修正後は Consumer 再起動

### 2. デバッグ方法
```ruby
# Consumer でのデバッグ
class ExampleConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      puts "🔍 Debug: #{message.inspect}"
      puts "📝 Payload: #{message.payload}"
      puts "🔑 Key: #{message.key}"
      puts "📊 Partition: #{message.partition}"
      puts "🕒 Timestamp: #{message.timestamp}"
    end
  end
end
```

### 3. テストデータ管理
```bash
# テストデータ送信用スクリプト
ruby consumer_test.rb        # 基本テストデータ
ruby final_test.rb          # 統合テストデータ
```

---

## 🔗 関連リンク

- [Karafka Documentation](https://karafka.io/docs)
- [Kafka Docker Images](https://hub.docker.com/r/confluentinc/cp-kafka/)
- [Rails Integration Guide](https://karafka.io/docs/Rails-Integration)

---

## 📋 チェックリスト

### 環境確認
- [ ] Docker が起動している
- [ ] Kafka/Zookeeper コンテナが起動している
- [ ] `final_test.rb` が成功する
- [ ] `bundle exec karafka server` が起動する

### 機能確認
- [ ] Producer でメッセージ送信できる
- [ ] Consumer でメッセージ受信できる
- [ ] Rails Web UI からメッセージ送信できる
- [ ] エラーハンドリングが適切に動作する

### 運用準備
- [ ] Consumer Group ID が適切に設定されている
- [ ] Topic設定が適切である
- [ ] ログ出力が適切に設定されている
- [ ] エラー監視が設定されている

---

**最終更新**: 2025-07-11  
**作成者**: Claude Code Assistant