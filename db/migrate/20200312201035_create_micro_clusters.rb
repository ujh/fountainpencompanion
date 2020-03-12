class CreateMicroClusters < ActiveRecord::Migration[6.0]
  def change
    create_table :micro_clusters do |t|
      t.text :simplified_brand_name, null: false
      t.text :simplified_line_name, default: ''
      t.text :simplified_ink_name, null: false

      t.timestamps
    end
    add_index :micro_clusters, [:simplified_brand_name, :simplified_line_name, :simplified_ink_name], unique: true, name: 'unique_micro_clusters'
  end
end
