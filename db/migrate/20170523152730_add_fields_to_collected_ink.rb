class AddFieldsToCollectedInk < ActiveRecord::Migration[5.0]
  def change
    add_column :collected_inks, :brand_name, :text
    add_column :collected_inks, :line_name, :text
    add_column :collected_inks, :ink_name, :text
    CollectedInk.delete_all
  end
end
