class RelaxPenMicroClusterRules < ActiveRecord::Migration[7.2]
  def change
    change_column_null(:pens_micro_clusters, :simplified_material, true)
    change_column_null(:pens_micro_clusters, :simplified_trim_color, true)
    change_column_null(:pens_micro_clusters, :simplified_filling_system, true)
  end
end
