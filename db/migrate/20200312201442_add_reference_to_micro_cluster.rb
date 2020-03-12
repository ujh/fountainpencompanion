class AddReferenceToMicroCluster < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_reference :collected_inks, :micro_cluster, foreign_key: true,  index: {algorithm: :concurrently}
  end
end
