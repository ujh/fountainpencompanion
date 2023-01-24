class CreateMacroClusters < ActiveRecord::Migration[6.0]
  def change
    create_table :macro_clusters do |t|
      t.string :brand_name, default: ""
      t.string :line_name, default: ""
      t.string :ink_name, default: ""
      t.string :color, limit: 7, default: "", null: false
      t.index %i[brand_name line_name ink_name], unique: true
      t.timestamps
    end
    safety_assured do
      add_reference :micro_clusters, :macro_cluster, foreign_key: true
    end
  end
end
