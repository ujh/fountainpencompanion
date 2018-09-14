class CreateNewInkNames < ActiveRecord::Migration[5.2]
  def change
    create_table :new_ink_names do |t|
      t.text :simplified_name, null: false, index: { unique: true }
      t.text :popular_name
      t.integer :ink_brand_id, null: false
      t.foreign_key :ink_brands
      t.timestamps
    end
  end
end
