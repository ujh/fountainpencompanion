class CreatePensModels < ActiveRecord::Migration[7.1]
  def change
    create_table :pens_models do |t|
      t.text :brand, null: false
      t.text :model, null: false

      t.timestamps

      t.index %i[brand model], unique: true
    end
  end
end
