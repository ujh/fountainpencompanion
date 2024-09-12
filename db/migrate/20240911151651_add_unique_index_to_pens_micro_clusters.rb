class AddUniqueIndexToPensMicroClusters < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index(
      :pens_micro_clusters,
      %i[simplified_brand simplified_model simplified_color],
      unique: true,
      algorithm: :concurrently,
      if_not_exists: true
    )
  end
end
