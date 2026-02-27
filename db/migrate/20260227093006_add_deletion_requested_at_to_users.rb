class AddDeletionRequestedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deletion_requested_at, :datetime
  end
end
