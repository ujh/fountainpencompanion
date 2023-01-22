class CreateInks < ActiveRecord::Migration[5.0]
  def change
    create_table :inks do |t|
      t.text :name, null: false
      t.integer :manufacturer_id, null: false
      t.foreign_key :manufacturers
      t.index %i[name manufacturer_id], unique: true
      t.timestamps
    end
  end
end
