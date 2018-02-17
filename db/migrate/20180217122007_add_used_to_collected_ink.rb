class AddUsedToCollectedInk < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :used, :boolean, default: false, null: false
  end
end
