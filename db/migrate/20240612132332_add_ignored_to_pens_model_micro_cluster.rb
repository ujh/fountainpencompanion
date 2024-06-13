class AddIgnoredToPensModelMicroCluster < ActiveRecord::Migration[7.1]
  def change
    add_column :pens_model_micro_clusters, :ignored, :boolean, default: false
  end
end
