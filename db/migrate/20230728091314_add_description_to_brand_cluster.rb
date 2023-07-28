class AddDescriptionToBrandCluster < ActiveRecord::Migration[7.0]
  def change
    add_column :brand_clusters, :description, :text, default: ""
  end
end
