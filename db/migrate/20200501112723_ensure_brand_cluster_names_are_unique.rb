class EnsureBrandClusterNamesAreUnique < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :brand_clusters, :name, unique: true, algorithm: :concurrently
  end
end
