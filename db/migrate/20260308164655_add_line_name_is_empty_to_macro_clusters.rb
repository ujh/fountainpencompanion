class AddLineNameIsEmptyToMacroClusters < ActiveRecord::Migration[8.1]
  def change
    add_column :macro_clusters, :line_name_is_empty, :boolean, default: false, null: false
  end
end
