class AddMissingIndicesToCollectedInk < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :collected_inks, :archived_on, algorithm: :concurrently
    add_index :collected_inks, %i[archived_on user_id], algorithm: :concurrently
  end
end
