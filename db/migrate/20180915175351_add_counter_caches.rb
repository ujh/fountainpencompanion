class AddCounterCaches < ActiveRecord::Migration[5.2]
  def change
    add_column :new_ink_names, :collected_inks_count, :integer, default: 0
    add_column :ink_brands, :new_ink_names_count, :integer, default: 0
  end
end
