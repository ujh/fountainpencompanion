class AddIgnoredColorsToMacroClusters < ActiveRecord::Migration[8.1]
  def change
    add_column :macro_clusters, :ignored_colors, :text, array: true, default: [], null: false
  end
end
