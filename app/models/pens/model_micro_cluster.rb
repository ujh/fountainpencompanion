class Pens::ModelMicroCluster < ApplicationRecord
  has_many :model_variants,
           foreign_key: :pens_model_micro_cluster_id,
           class_name: "Pens::ModelVariant",
           dependent: :nullify

  belongs_to :model, optional: true, class_name: "Pens::Model", foreign_key: :pens_model_id

  paginates_per 100

  scope :unassigned, -> { where(pens_model_id: nil) }
  scope :without_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }
  scope :ordered, lambda { order(:simplified_brand, :simplified_model) }
end
