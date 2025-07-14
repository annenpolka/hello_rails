class CreateFriendships < ActiveRecord::Migration[8.0]
  def change
    create_table :friendships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :friend, null: false, foreign_key: { to_table: :users }
      t.string :status, default: 'pending'

      t.timestamps
    end
    
    add_index :friendships, [:user_id, :friend_id], unique: true
    add_index :friendships, :status
  end
end
