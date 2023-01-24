class ValidateBrandClusterForeignKeyToMacroCluster < ActiveRecord::Migration[
  6.0
]
  def change
    validate_foreign_key :macro_clusters, :brand_clusters, validate: false
  end
end
