class AddSimplifiedFieldsToCollectedInk < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :simplified_brand_name, :string, limit: 100
    add_column :collected_inks, :simplified_line_name, :string, limit: 100
    add_column :collected_inks, :simplified_ink_name, :string, limit: 100
  end
end
