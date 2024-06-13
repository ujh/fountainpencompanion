module Pens
  class UpdateModelMicroCluster
    include Sidekiq::Worker

    def perform(pens_model_micro_cluster_id)
      cluster = Pens::ModelMicroCluster.find(pens_model_micro_cluster_id)
      return unless cluster.pens_model_id

      Pens::UpdateModel.perform_async(cluster.pens_model_id)
    end
  end
end
