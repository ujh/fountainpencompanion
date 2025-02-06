class AddIngoredToMicroCluster < ActiveRecord::Migration[6.0]
  def change
    safety_assured { add_column :micro_clusters, :ignored, :boolean, default: false }
  end
end
