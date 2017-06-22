class RenameManufacturerToBrand < ActiveRecord::Migration[5.0]
  def change
    rename_table :manufacturers, :brands
    rename_column :inks, :manufacturer_id, :brand_id
  end
end
