class CreatePens < ActiveRecord::Migration[5.1]
  def change
    create_table :pens do |t|
      t.string :brand, null: false
      t.string :model, null: false
      t.integer :user_id, null: false
      t.foreign_key :users
      t.timestamps
    end
  end
end
