class AddUniqueIndexToInkBrand < ActiveRecord::Migration[5.2]
  def change
    add_index :ink_brands, :simplified_name, unique: true
  end
end
