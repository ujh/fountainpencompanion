class RemoveUnusedTables < ActiveRecord::Migration[5.0]
  def up
    remove_column :collected_inks, :ink_id
    drop_table :inks
    drop_table :lines
    drop_table :brands
  end
end
