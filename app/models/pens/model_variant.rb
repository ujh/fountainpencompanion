class Pens::ModelVariant < ApplicationRecord
  has_many :micro_clusters,
           foreign_key: :pens_model_variant_id,
           class_name: "Pens::MicroCluster"
  has_many :collected_pens, through: :micro_clusters

  paginates_per 100

  scope :ordered,
        lambda {
          order(:brand, :model, :color, :material, :trim_color, :filling_system)
        }
end
