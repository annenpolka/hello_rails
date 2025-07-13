module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # 開発環境では認証なしで接続を許可
      if Rails.env.development?
        self.current_user = "anonymous_user"
        logger.add_tags("ActionCable", "User #{current_user}")
      else
        set_current_user || reject_unauthorized_connection
      end
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end
  end
end
