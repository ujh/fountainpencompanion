module Pens
  class AssignModelMicroCluster
    include Sidekiq::Worker

    def perform(model_variant_id)
      model_variant = Pens::ModelVariant.find(model_variant_id)
      cluster =
        Pens::ModelMicroCluster.find_or_create_by!(
          cluster_attributes(model_variant)
        )
      model_variant.update!(model_micro_cluster: cluster)
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end

    private

    def cluster_attributes(model_variant)
      {
        simplified_brand: Simplifier.simplify(model_variant.brand),
        simplified_model: Simplifier.simplify(model_variant.model)
      }
    end
  end
end
