class RemoveUniqueIndexOnCurrentlyInked < ActiveRecord::Migration[5.1]
  def change
    remove_index :currently_inked, %i[user_id collected_pen_id]
  end
end
