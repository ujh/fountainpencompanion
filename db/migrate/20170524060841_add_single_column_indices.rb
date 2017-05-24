class AddSingleColumnIndices < ActiveRecord::Migration[5.0]
  def change
    add_index :collected_inks, :brand_name
    add_index :collected_inks, :line_name
    add_index :collected_inks, :ink_name
  end
end
