class AddColumnsToCollectedPen < ActiveRecord::Migration[7.1]
  def change
    add_column :collected_pens, :material, :text, default: ""
    add_column :collected_pens, :price, :text, default: ""
    add_column :collected_pens, :trim_color, :text, default: ""
    add_column :collected_pens, :filling_system, :text, default: ""
  end
end
