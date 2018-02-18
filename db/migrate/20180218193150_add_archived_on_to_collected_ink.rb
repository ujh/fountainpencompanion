class AddArchivedOnToCollectedInk < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :archived_on, :date
  end
end
