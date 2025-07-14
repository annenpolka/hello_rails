Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  resources :products
  root "products#index"

  # ActionCable routes
  mount ActionCable.server => '/cable'

  # Kafka integration routes
  get "kafka", to: "kafka#index", as: :kafka_index
  get "kafka/websocket", to: "kafka#websocket", as: :kafka_websocket
  get "kafka/debug", to: "kafka#debug", as: :kafka_debug
  get "kafka/test_broadcast", to: "kafka#test_broadcast", as: :kafka_test_broadcast
  post "kafka/broadcast_from_consumer", to: "kafka#broadcast_from_consumer"
  post "kafka/send", to: "kafka#send_message", as: :kafka_send_message
  post "kafka/clear", to: "kafka#clear_messages", as: :kafka_clear_messages
  post "kafka/send_test_notification", to: "kafka#send_test_notification", as: :kafka_send_test_notification
  post "kafka/send_friend_request", to: "kafka#send_friend_request", as: :kafka_send_friend_request
  post "kafka/accept_friend_request", to: "kafka#accept_friend_request", as: :kafka_accept_friend_request
  delete "kafka/delete_all_friendships", to: "kafka#delete_all_friendships", as: :kafka_delete_all_friendships
end
