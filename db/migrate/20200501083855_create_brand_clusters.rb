class CreateBrandClusters < ActiveRecord::Migration[6.0]
  def change
    create_table :brand_clusters do |t|
      t.string :name

      t.timestamps
    end
  end
end
