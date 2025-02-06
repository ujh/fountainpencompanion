class CreatePensBrands < ActiveRecord::Migration[7.2]
  def change
    create_table :pens_brands do |t|
      t.string :name, null: false, index: { unique: true }

      t.timestamps
    end

    safety_assured { add_reference :pens_models, :pens_brand, foreign_key: true, null: true }
  end
end
