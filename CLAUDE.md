# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要
HelloRailsアプリケーション - Rails 8.0.2を使用したRailsガイド学習プロジェクト

## 環境とフレームワーク
- Rails 8.0.2
- Ruby (Bundler管理)
- SQLite3データベース
- Hotwire (Turbo + Stimulus)
- Solid Cache/Queue/Cable for Rails 8の新機能
- Kamal for Docker deployment

## 開発コマンド

### 基本コマンド
- サーバー起動: `bin/rails server`
- コンソール: `bin/rails console`
- データベース作成: `bin/rails db:create`
- マイグレーション実行: `bin/rails db:migrate`
- マイグレーション取り消し: `bin/rails db:rollback`
- シード実行: `bin/rails db:seed`

### コード品質とテスト
- テスト実行: `bin/rails test`
- システムテスト: `bin/rails test:system`
- 単体テスト: `bin/rails test test/models/モデル名_test.rb`
- コードスタイル: `bin/rubocop`
- セキュリティチェック: `bin/brakeman`

### ジェネレータ
- モデル生成: `bin/rails generate model ModelName field:type`
- コントローラー生成: `bin/rails generate controller ControllerName action`
- リソース生成: `bin/rails generate resource ResourceName field:type`

## アーキテクチャ構成

### Rails 8の特徴
- **Solid三兄弟**: Cache、Queue、Cableをデータベースで管理
- **Propshaft**: 新しいアセットパイプライン
- **Hotwire**: TurboとStimulusによるSPA-like体験

### データベース設計
- 開発環境: SQLite3 (`storage/development.sqlite3`)
- 本番環境: 複数データベース構成（primary, cache, queue, cable）

### 現在のモデル
- `Product`: 基本的なProductモデル（name属性のみ）

## 学習の進め方
このプロジェクトはRailsガイドの学習用です。以下の順序で進めることを推奨：

1. Active Recordの基本（モデル、バリデーション、アソシエーション）
2. ルーティングとコントローラー
3. ビューとヘルパー
4. Hotwireの活用
5. Rails 8の新機能探索

## Kafka/Karafka 統合 (Redpanda対応)
- **Karafka Gem**: Apache Kafka API互換のRedpandaメッセージング統合
- **設定ファイル**: `karafka.rb` (Redpanda最適化済み)
- **Consumer**: `app/consumers/` ディレクトリ
- **Docker環境**: `docker-compose.yml` でRedpanda管理（ZooKeeper不要）
- **管理UI**: Redpanda Console (http://localhost:8080)

### Redpanda関連コマンド
- 環境起動: `docker-compose up -d`
- 環境停止: `docker-compose down`
- ログ確認: `docker-compose logs`
- Consumer起動: `bundle exec karafka server`
- 管理コンソール: `http://localhost:8080`

### Redpanda vs Kafka
- **性能**: 10倍低レイテンシ、3倍少ないリソース
- **運用**: ZooKeeper不要、JVM不要
- **互換性**: Kafka API 100%互換
- **開発**: 単一ノードで完全機能
- **監視**: 統合WebUI付き

## 注意事項
- 日本語をデフォルト言語として使用
- 実装とドキュメントの同時更新
- Rails 8固有の機能を活用したコーディング