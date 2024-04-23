module Pens
  class UpdateMicroCluster
    include Sidekiq::Worker

    def perform(pens_micro_cluster_id)
      cluster = Pens::MicroCluster.find(pens_micro_cluster_id)
      return unless cluster.pens_model_variant_id

      Pens::UpdateModelVariant.perform_async(cluster.pens_model_variant_id)
    end
  end
end
