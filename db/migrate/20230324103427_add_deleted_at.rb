class AddDeletedAt < ActiveRecord::Migration[7.0]
  def change
    add_column :collected_inks, :deleted_at, :timestamp
    add_column :collected_pens, :deleted_at, :timestamp
  end
end
