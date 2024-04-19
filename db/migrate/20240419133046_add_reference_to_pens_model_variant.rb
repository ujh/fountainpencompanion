class AddReferenceToPensModelVariant < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      add_reference :pens_micro_clusters, :pens_model_variant, foreign_key: true
    end
  end
end
