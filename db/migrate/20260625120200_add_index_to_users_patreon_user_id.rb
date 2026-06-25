class AddIndexToUsersPatreonUserId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users,
              :patreon_user_id,
              unique: true,
              where: "patreon_user_id IS NOT NULL",
              algorithm: :concurrently
  end
end
