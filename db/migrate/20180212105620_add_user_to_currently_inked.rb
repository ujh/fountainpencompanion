class AddUserToCurrentlyInked < ActiveRecord::Migration[5.1]
  def change
    add_reference :currently_inkeds, :user, foreign_key: true, null: false
  end
end
