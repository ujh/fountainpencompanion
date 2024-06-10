class CreatePensModelMicroClusters < ActiveRecord::Migration[7.1]
  def change
    create_table :pens_model_micro_clusters do |t|
      t.text :simplified_brand, null: false
      t.text :simplified_model, null: false

      t.timestamps

      t.index %i[simplified_brand simplified_model], unique: true
    end
  end
end
