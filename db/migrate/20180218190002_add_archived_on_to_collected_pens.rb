class AddArchivedOnToCollectedPens < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_pens, :archived_on, :date
  end
end
