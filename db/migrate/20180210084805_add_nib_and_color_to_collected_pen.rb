class AddNibAndColorToCollectedPen < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_pens, :nib, :string, limit: 100
    add_column :collected_pens, :color, :string, limit: 100
  end
end
