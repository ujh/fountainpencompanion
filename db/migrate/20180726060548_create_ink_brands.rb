class CreateInkBrands < ActiveRecord::Migration[5.2]
  def change
    create_table :ink_brands do |t|
      t.text :simplified_name
      t.text :popular_name
      t.timestamps
    end
  end
end
