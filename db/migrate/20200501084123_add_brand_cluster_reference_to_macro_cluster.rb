class AddBrandClusterReferenceToMacroCluster < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_reference :macro_clusters, :brand_cluster, index: { algorithm: :concurrently }
  end
end
