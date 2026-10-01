class CreateMacroClusterPopularities < ActiveRecord::Migration[8.1]
  def change
    create_view :macro_cluster_popularities, materialized: true
    # Unique index is required to refresh the view concurrently. The view was just created, so
    # nothing can be blocked by building the index.
    safety_assured { add_index :macro_cluster_popularities, :macro_cluster_id, unique: true }
  end
end
