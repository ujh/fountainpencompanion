class RemoveInkBrandIdFromCollectedInk < ActiveRecord::Migration[5.2]
  def change
    remove_column :collected_inks, :ink_brand_id
  end
end
