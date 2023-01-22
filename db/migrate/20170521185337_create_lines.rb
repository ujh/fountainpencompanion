class CreateLines < ActiveRecord::Migration[5.0]
  def change
    create_table :lines do |t|
      t.text :name, null: false
      t.integer :brand_id, null: false
      t.foreign_key :brands
      t.index %i[name brand_id], unique: true
      t.timestamps
    end
  end
end
