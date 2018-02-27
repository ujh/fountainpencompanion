class AddIndexToCollectedInk < ActiveRecord::Migration[5.2]
  def change
    add_index :collected_inks, :simplified_ink_name
  end
end
