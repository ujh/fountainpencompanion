class AddBrandClusterForeignKeyToMacroCluster < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :macro_clusters, :brand_clusters, validate: false
  end
end
