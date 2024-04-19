class Pens::ModelVariant < ApplicationRecord
  has_many :micro_clusters,
           foreign_key: :pens_model_variant_id,
           class_name: "Pens::MicroCluster"
end
