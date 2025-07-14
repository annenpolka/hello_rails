# frozen_string_literal: true

class KarafkaApp < Karafka::App
  setup do |config|
    # Redpanda broker configuration (Kafka API compatible)
    config.kafka = { 
      'bootstrap.servers': ENV.fetch('REDPANDA_BROKERS', '127.0.0.1:9092'),
      # Optimized settings for Redpanda
      'acks': 'all',
      'retries': 3,
      'retry.backoff.ms': 100,
      'delivery.timeout.ms': 120_000,
      'request.timeout.ms': 30_000,
      # Redpanda specific optimizations for async performance
      'batch.size': 16_384,
      'linger.ms': 5,
      'compression.type': 'snappy',
      # Async producer optimizations
      'queue.buffering.max.messages': 100_000,
      'queue.buffering.max.kbytes': 1_048_576,
      'batch.num.messages': 10_000,
      'max.in.flight.requests.per.connection': 5
    }
    config.client_id = 'hello_rails_app_redpanda'

    # IMPORTANT: Customize this group_id with your application name.
    # The group_id should be unique per application to properly track message consumption.
    # Example: config.group_id = 'inventory_service_consumer'
    #
    # Note: Advanced features and custom routing configurations may define their own consumer
    # groups. These should also be uniquely named per application to avoid conflicts.
    # For the advanced features, subscription groups and consumer groups in your routing
    # configuration, follow the same uniqueness principle.
    #
    # For more details on consumer groups and routing configuration, please refer to the
    # Karafka documentation: https://karafka.io/docs
    config.group_id = 'hello_rails_app_redpanda_consumer'
    # Recreate consumers with each batch. This will allow Rails code reload to work in the
    # development mode. Otherwise Karafka process would not be aware of code changes
    config.consumer_persistence = !Rails.env.development?
  end

  # Comment out this part if you are not using instrumentation and/or you are not
  # interested in logging events for certain environments. Since instrumentation
  # notifications add extra boilerplate, if you want to achieve max performance,
  # listen to only what you really need for given environment.
  Karafka.monitor.subscribe(
    Karafka::Instrumentation::LoggerListener.new(
      # Karafka, when the logger is set to info, produces logs each time it polls data from an
      # internal messages queue. This can be extensive, so you can turn it off by setting below
      # to false.
      log_polling: true
    )
  )
  # Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

  # This logger prints the producer development info using the Karafka logger.
  # It is similar to the consumer logger listener but producer oriented.
  Karafka.producer.monitor.subscribe(
    WaterDrop::Instrumentation::LoggerListener.new(
      # Log producer operations using the Karafka logger
      Karafka.logger,
      # If you set this to true, logs will contain each message details
      # Please note, that this can be extensive
      log_messages: false
    )
  )

  # You can subscribe to all consumer related errors and record/track them that way
  #
  # Karafka.monitor.subscribe 'error.occurred' do |event|
  #   type = event[:type]
  #   error = event[:error]
  #   details = (error.backtrace || []).join("\n")
  #   ErrorTracker.send_error(error, type, details)
  # end

  # You can subscribe to all producer related errors and record/track them that way
  # Please note, that producer and consumer have their own notifications pipeline so you need to
  # setup error tracking independently for each of them
  #
  # Karafka.producer.monitor.subscribe('error.occurred') do |event|
  #   type = event[:type]
  #   error = event[:error]
  #   details = (error.backtrace || []).join("\n")
  #   ErrorTracker.send_error(error, type, details)
  # end

  routes.draw do
    # Uncomment this if you use Karafka with ActiveJob
    # You need to define the topic per each queue name you use
    # active_job_topic :default
    
    # 一般的なメッセージ処理（デモ・テスト用）
    topic :example do
      consumer ExampleConsumer
      config(partitions: 3, replication_factor: 1)
    end
    
    # ユーザー通知（フレンド申請、承認、アクティビティ等）
    topic :user_notifications do
      consumer UserNotificationsConsumer
      # パーティション分散でスケーラビリティ確保
      config(partitions: 6, replication_factor: 1, 'cleanup.policy': 'delete')
    end
    
    # フレンド関連アクティビティ
    topic :friend_activities do
      consumer FriendActivitiesConsumer  
      config(partitions: 3, replication_factor: 1, 'cleanup.policy': 'delete')
    end
  end
end

# Karafka now features a Web UI!
# Visit the setup documentation to get started and enhance your experience.
#
# https://karafka.io/docs/Web-UI-Getting-Started
