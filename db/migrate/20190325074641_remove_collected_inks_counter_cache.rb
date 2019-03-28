class RemoveCollectedInksCounterCache < ActiveRecord::Migration[5.2]
  def change
    remove_column :new_ink_names, :collected_inks_count, :integer, default: 0
  end
end
