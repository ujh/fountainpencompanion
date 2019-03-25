class RemoveInkBrandsCounterCache < ActiveRecord::Migration[5.2]
  def change
    remove_column :ink_brands, :new_ink_names_count, :integer, default: 0
  end
end
