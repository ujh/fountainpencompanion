class RemovePendingFromFriendships < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :friendships, :pending, :boolean }
  end
end
