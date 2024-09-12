class RemoveExtraPensMicroClusterColumns < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_columns(
        :pens_micro_clusters,
        :simplified_material,
        :simplified_trim_color,
        :simplified_filling_system,
        type: :string
      )
    end
  end
end
