class AddIngoredToPensMicroCluster < ActiveRecord::Migration[7.1]
  def change
    add_column :pens_micro_clusters, :ignored, :boolean, default: false
  end
end
