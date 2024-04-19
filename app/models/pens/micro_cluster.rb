class Pens::MicroCluster < ApplicationRecord
  has_many :collected_pens, foreign_key: :pens_micro_cluster
  belongs_to :model_variant,
             optional: true,
             class_name: "Pens::ModelVariant",
             foreign_key: :pens_model_variant_id

  scope :unassigned, -> { where(pens_model_variant_id: nil) }
  scope :without_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }
end
