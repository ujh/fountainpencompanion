class AddReferenceFromModelClusterToModel < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      add_reference :pens_model_micro_clusters, :pens_model, foreign_key: true
    end
  end
end
