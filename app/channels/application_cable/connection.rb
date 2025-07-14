module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # セッションベースの認証を試行、失敗時は匿名ユーザーとして接続
      set_current_user || set_anonymous_user
      logger.add_tags("ActionCable", "User #{current_user.is_a?(User) ? current_user.email_address : current_user}")
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
          true
        else
          false
        end
      end
      
      def set_anonymous_user
        self.current_user = "anonymous_user"
        true
      end
  end
end
