# Redpanda/Kafka トピック設計分析

## 現在の設計: ユーザーごとトピック

### 問題点
1. **スケーラビリティ**: ユーザー数 = トピック数の線形増加
2. **管理負荷**: メタデータ増大、Consumer管理の複雑化
3. **リソース効率**: パーティション活用不十分

## 推奨設計: 機能別トピック + パーティション分散

### 設計案1: 少数トピック方式
```ruby
# config/kafka_topics.rb
KAFKA_TOPICS = {
  user_notifications: {
    partitions: 10,
    replication_factor: 3,
    key_strategy: :user_id_hash
  },
  friend_activities: {
    partitions: 5,
    replication_factor: 3,
    key_strategy: :activity_type_hash
  }
}

# app/services/notification_service.rb
class NotificationService
  def send_notification(user_id, notification)
    Karafka.producer.produce_sync(
      topic: 'user_notifications',
      key: user_id.to_s,  # パーティション分散
      payload: notification.to_json
    )
  end
end

# app/consumers/user_notifications_consumer.rb
class UserNotificationsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      user_id = extract_user_id(message.key)
      payload = JSON.parse(message.payload)
      
      # WebSocket配信
      ActionCable.server.broadcast(
        "user_#{user_id}_channel",
        { action: 'notification', payload: payload }
      )
    end
  end
  
  private
  
  def extract_user_id(key)
    key.to_i
  end
end
```

### 設計案2: 地理的/論理分散
```ruby
# ユーザーを地域やグループで分散
def notification_topic(user)
  region = user.region || 'global'
  "#{region}_user_notifications"
end

# 例: asia_user_notifications, eu_user_notifications
```

### 設計案3: 階層化設計
```ruby
# 緊急度やユーザータイプによる分離
NOTIFICATION_TOPICS = {
  high_priority: 'urgent_notifications',    # VIP、課金ユーザー
  normal: 'standard_notifications',         # 一般ユーザー
  batch: 'bulk_notifications'              # まとめ通知
}
```

## Redpanda最適化のメリット

### 現在の実装への影響
```ruby
# karafka.rb - 最適化版
class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      'bootstrap.servers': '127.0.0.1:9092',
      # Redpanda最適化
      'acks': 'all',
      'batch.size': 32_768,        # より大きなバッチ
      'linger.ms': 10,             # 少し長めの待機
      'compression.type': 'lz4'    # Redpandaで高速
    }
  end

  routes.draw do
    # 少数の最適化されたトピック
    topic :user_notifications do
      consumer UserNotificationsConsumer
      config(partitions: 12, replication_factor: 1)
    end
    
    topic :friend_activities do
      consumer FriendActivitiesConsumer
      config(partitions: 6, replication_factor: 1)
    end
  end
end
```

## 性能比較

| 設計 | ユーザー1万人時 | ユーザー10万人時 | 管理負荷 |
|------|---------------|----------------|----------|
| ユーザー別トピック | 1万トピック | 10万トピック | 高 |
| 機能別+パーティション | 3-5トピック | 3-5トピック | 低 |
| 地域別分散 | 15-20トピック | 50-100トピック | 中 |

## 移行計画

### Phase 1: 並行運用
```ruby
# 旧システムと新システムの並行運用
def send_notification(user, notification)
  # 新設計で送信
  send_to_partitioned_topic(user, notification)
  
  # 旧設計も継続（フォールバック）
  send_to_user_topic(user, notification) if Rails.env.development?
end
```

### Phase 2: 段階的移行
1. 新規ユーザーは新設計
2. 既存ユーザーの段階移行
3. 旧トピック削除

### Phase 3: 監視・最適化
- Consumer Lag監視
- パーティション再バランス
- スループット測定

## 結論

**現在の設計**: 学習・プロトタイプには適しているが本格運用には不向き
**推奨設計**: 機能別トピック + パーティション分散でスケーラビリティ確保
**Redpanda活用**: 単一ノードでも高性能、運用コスト削減