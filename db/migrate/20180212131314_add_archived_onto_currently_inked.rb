class AddArchivedOntoCurrentlyInked < ActiveRecord::Migration[5.1]
  def change
    add_column :currently_inked, :archived_on, :date
  end
end
