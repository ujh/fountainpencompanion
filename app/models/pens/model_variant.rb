class Pens::ModelVariant < ApplicationRecord
  has_many :micro_clusters,
           foreign_key: :pens_model_variant_id,
           class_name: "Pens::MicroCluster"

  scope :ordered,
        -> do
          order(:brand, :model, :color, :material, :trim_color, :filling_system)
        end
end
