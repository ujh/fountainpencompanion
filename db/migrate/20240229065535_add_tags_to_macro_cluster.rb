class AddTagsToMacroCluster < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :macro_clusters, :tags, :text, array: true, default: []
    add_index :macro_clusters, :tags, using: "gin", algorithm: :concurrently
  end
end
