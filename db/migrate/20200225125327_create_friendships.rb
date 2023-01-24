class CreateFriendships < ActiveRecord::Migration[6.0]
  def change
    create_table :friendships do |t|
      t.references :sender, foreign_key: { to_table: :users }, null: false
      t.references :friend, foreign_key: { to_table: :users }, null: false
      t.boolean :pending, default: true
      t.boolean :approved, default: false
      t.timestamps
    end
  end
end
