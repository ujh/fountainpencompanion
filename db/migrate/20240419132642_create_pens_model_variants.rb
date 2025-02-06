class CreatePensModelVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :pens_model_variants do |t|
      t.text :brand, null: false
      t.text :model, null: false
      t.text :color, null: false, default: ""
      t.text :material, null: false, default: ""
      t.text :trim_color, null: false, default: ""
      t.text :filling_system, null: false, default: ""

      t.timestamps

      t.index %i[brand model color material trim_color filling_system], unique: true
    end
  end
end
