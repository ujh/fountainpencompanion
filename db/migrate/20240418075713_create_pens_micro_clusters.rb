class CreatePensMicroClusters < ActiveRecord::Migration[7.1]
  def change
    create_table :pens_micro_clusters do |t|
      t.text :simplified_brand, null: false
      t.text :simplified_model, null: false
      t.text :simplified_color, null: false
      t.text :simplified_material, null: false
      t.text :simplified_trim_color, null: false
      t.text :simplified_filling_system, null: false

      t.timestamps

      t.index %i[
                simplified_brand
                simplified_model
                simplified_color
                simplified_material
                simplified_trim_color
                simplified_filling_system
              ],
              unique: true
    end
  end
end
