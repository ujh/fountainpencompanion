class ReferenceModelMicroClusterFromModelVariant < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      add_reference :pens_model_variants, :pens_model_micro_cluster, foreign_key: true
    end
  end
end
