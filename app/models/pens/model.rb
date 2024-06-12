class Pens::Model < ApplicationRecord
  has_many :model_micro_clusters,
           foreign_key: :pens_model_id,
           class_name: "Pens::ModelMicroCluster",
           dependent: :nullify

  paginates_per 100

  scope :ordered, lambda { order(:brand, :model) }

  def self.search(query)
    return self if query.blank?

    query = query.split(/\s+/).join("%")
    joins(model_micro_clusters: :model_variants).where(
      <<~SQL,
      CONCAT(model_variants.brand, model_variants.model, model_variants.color, model_variants.material)
      ILIKE ?
    SQL
      "%#{query}%"
    ).group("pens_models.id")
  end
end
