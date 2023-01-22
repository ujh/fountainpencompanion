class AddUniqueIndexToCurrentlyInked < ActiveRecord::Migration[5.1]
  def change
    add_index :currently_inked, %i[user_id collected_pen_id], unique: true
  end
end
