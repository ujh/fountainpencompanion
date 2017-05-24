class ChangeCollectedInkColumnsToString < ActiveRecord::Migration[5.0]
  def change
    change_column :collected_inks, :brand_name, :string, limit: 100, null: false
    change_column :collected_inks, :line_name, :string, limit: 100
    change_column :collected_inks, :ink_name, :string, limit: 100, null: false
  end
end
