class Friendship < ApplicationRecord
  belongs_to :user
  belongs_to :friend, class_name: 'User'
  
  validates :status, inclusion: { in: %w[pending accepted rejected] }
  validates :user_id, uniqueness: { scope: :friend_id }
  validate :cannot_friend_self
  
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :rejected, -> { where(status: 'rejected') }
  
  after_create :send_friend_request_notification
  after_update :send_status_change_notification
  
  def accept!
    update!(status: 'accepted')
    # 相互フレンド関係を作成
    create_mutual_friendship unless mutual_friendship_exists?
  end
  
  def reject!
    update!(status: 'rejected')
  end
  
  private
  
  def cannot_friend_self
    errors.add(:friend_id, "can't be the same as user") if user_id == friend_id
  end
  
  def mutual_friendship_exists?
    Friendship.exists?(user: friend, friend: user, status: 'accepted')
  end
  
  def create_mutual_friendship
    Friendship.create!(
      user: friend,
      friend: user,
      status: 'accepted'
    )
  end
  
  def send_friend_request_notification
    return unless status == 'pending'
    FriendNotificationService.send_friend_request_notification(self)
  end
  
  def send_status_change_notification
    return unless saved_change_to_status?
    
    case status
    when 'accepted'
      FriendNotificationService.send_friend_accepted_notification(self)
    end
  end
end
