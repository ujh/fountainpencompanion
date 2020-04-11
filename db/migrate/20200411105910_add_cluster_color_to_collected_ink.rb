class AddClusterColorToCollectedInk < ActiveRecord::Migration[6.0]
  def up
    add_column :collected_inks, :cluster_color, :string, limit: 7
    change_column_default :collected_inks, :cluster_color, ""
  end

  def down
    remove_column :collected_inks, :cluster_color
  end
end
