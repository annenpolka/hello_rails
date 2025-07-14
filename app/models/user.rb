class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  
  # フレンド機能
  has_many :friendships, dependent: :destroy
  has_many :friends, through: :friendships, source: :friend
  has_many :incoming_friendships, class_name: 'Friendship', foreign_key: 'friend_id', dependent: :destroy
  has_many :pending_friends, -> { where(friendships: { status: 'pending' }) }, through: :incoming_friendships, source: :user

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  def send_friend_request(friend)
    return false if self == friend
    return false if friendship_exists_with?(friend)
    
    friendships.create(friend: friend, status: 'pending')
  end
  
  def accept_friend_request(friend)
    friendship = incoming_friendships.find_by(user: friend, status: 'pending')
    friendship&.accept!
  end
  
  def reject_friend_request(friend)
    friendship = incoming_friendships.find_by(user: friend, status: 'pending')
    friendship&.reject!
  end
  
  def friends_with?(user)
    friendships.accepted.exists?(friend: user)
  end
  
  def friendship_exists_with?(user)
    friendships.exists?(friend: user) || incoming_friendships.exists?(user: user)
  end
end
