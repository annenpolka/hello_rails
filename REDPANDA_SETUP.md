# Redpanda セットアップガイド

## 概要

このプロジェクトでは、Apache KafkaからRedpandaに移行しました。RedpandaはKafka API完全互換でありながら、ZooKeeper不要、JVM不要の高性能ストリーミングプラットフォームです。

## 特徴

### Redpanda vs Kafka
- **性能**: 10倍低レイテンシ、3倍少ないリソース使用量
- **運用**: ZooKeeper不要、JVM不要のシンプル構成
- **互換性**: Kafka API 100%互換（既存のKarafkaコード変更不要）
- **開発**: 単一ノードで完全機能が利用可能
- **監視**: 統合WebUI（Redpanda Console）付き

## セットアップ手順

### 1. 自動セットアップ（一本化）

```bash
# 統合されたDocker Composeで起動
docker-compose up -d
```

### 2. 起動確認

```bash
# サービス状態確認
docker-compose ps

# ログ確認
docker-compose logs redpanda-init
```

## サービス構成

### Redpanda (メインブローカー)
- **Kafka API**: `localhost:9092`
- **Admin API**: `localhost:9644`
- **Schema Registry**: `localhost:8081`
- **HTTP Proxy**: `localhost:8082`

### Redpanda Console (管理UI)
- **Web UI**: `http://localhost:8080`
- トピック管理、メッセージ閲覧、パフォーマンス監視

### Redis (ActionCable用)
- **接続**: `localhost:6379`
- WebSocket接続の状態管理

## 開発ワークフロー

### 1. 環境起動

```bash
# Redpanda環境起動（自動初期化含む）
docker-compose up -d

# Rails サーバー起動
bin/rails server

# Karafka Consumer起動（別ターミナル）
bundle exec karafka server
```

### 2. メッセージング確認

1. **Railsアプリ**: `http://localhost:3000/kafka`
2. **Redpanda Console**: `http://localhost:8080`
3. **WebSocket接続**: `http://localhost:3000/kafka/websocket`

### 3. メッセージ送信テスト

```bash
# Railsコンソールからメッセージ送信
bin/rails console

# Producer経由でメッセージ送信
Karafka.producer.produce_sync(topic: 'example', payload: { content: 'テストメッセージ' }.to_json)
```

## 設定ファイル説明

### karafka.rb
- Redpanda接続設定（最適化済み）
- 圧縮、バッチング、リトライ設定
- 環境変数による接続先切り替え

### docker-compose.yml
- Redpanda + Console + Redis + 初期化を統合
- 開発環境向け最適化設定
- ヘルスチェック、自動再起動設定
- トピック自動作成機能

## トラブルシューティング

### よくある問題

1. **接続タイムアウト**
   ```bash
   # サービス状態確認
   docker-compose ps
   
   # ログ確認
   docker-compose logs redpanda
   ```

2. **ポート競合**
   ```bash
   # ポート使用状況確認
   lsof -i :9092
   lsof -i :8080
   ```

3. **メッセージが消費されない**
   ```bash
   # Consumer起動確認
   bundle exec karafka server
   
   # Consumer グループ確認
   rpk group list
   ```

### デバッグコマンド

```bash
# クラスター情報
curl http://localhost:9644/v1/cluster/health_overview

# トピック一覧
rpk topic list --brokers localhost:9092

# Consumer グループ確認
rpk group list --brokers localhost:9092
```

## 本番環境への展開

### 設定変更点

1. **セキュリティ**
   - TLS/SSL有効化
   - SASL認証設定
   - ネットワーク分離

2. **パフォーマンス**
   - 複数ブローカー構成
   - レプリケーション設定
   - リソース配分最適化

3. **監視**
   - メトリクス収集
   - アラート設定
   - ログ集約

### 参考リンク

- [Redpanda Documentation](https://docs.redpanda.com/)
- [Karafka Framework](https://karafka.io/)
- [Redpanda vs Kafka Performance](https://redpanda.com/blog/redpanda-vs-kafka-performance-benchmark)