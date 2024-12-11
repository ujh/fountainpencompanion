class RemoveFriendshipsTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :friendships
  end
end
