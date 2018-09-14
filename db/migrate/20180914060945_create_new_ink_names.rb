class CreateNewInkNames < ActiveRecord::Migration[5.2]
  def change
    create_table :new_ink_names do |t|
      t.text :simplified_name, null: false
      t.text :popular_name
      t.integer :ink_brand_id, null: false
      t.foreign_key :ink_brands
      t.timestamps
      t.index [:simplified_name, :ink_brand_id], unique: true
    end
  end
end
