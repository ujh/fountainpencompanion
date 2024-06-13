class Pens::Model < ApplicationRecord
  has_many :model_micro_clusters,
           foreign_key: :pens_model_id,
           class_name: "Pens::ModelMicroCluster",
           dependent: :nullify
  has_many :model_variants, through: :model_micro_clusters

  paginates_per 100

  scope :ordered, lambda { order(:brand, :model) }

  def self.search(query)
    return self if query.blank?

    query = query.split(/\s+/).join("%")
    joins(model_micro_clusters: :model_variants).where(
      <<~SQL,
      CONCAT(pens_model_variants.brand, pens_model_variants.model)
      ILIKE ?
    SQL
      "%#{query}%"
    ).group("pens_models.id")
  end
end
