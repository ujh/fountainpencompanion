class RerunPenEmbeddings < ActiveRecord::Migration[8.0]
  def change
    Pens::ModelVariant.pluck(:id).each { |mv_id| Pens::UpdateModelVariant.perform_async(mv_id) }
    Pens::Model.pluck(:id).each { |model_id| Pens::UpdateModel.perform_async(model_id) }
  end
end
