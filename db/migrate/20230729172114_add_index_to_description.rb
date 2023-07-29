class AddIndexToDescription < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :brand_clusters, :description, algorithm: :concurrently
    add_index :macro_clusters, :description, algorithm: :concurrently
  end
end
