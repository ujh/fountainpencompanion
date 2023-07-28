class AddDescriptionToMacroCluster < ActiveRecord::Migration[7.0]
  def change
    add_column :macro_clusters, :description, :text, default: ""
  end
end
