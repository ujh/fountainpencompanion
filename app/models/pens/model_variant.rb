class Pens::ModelVariant < ApplicationRecord
  has_many :micro_clusters,
           foreign_key: :pens_model_variant_id,
           class_name: "Pens::MicroCluster",
           dependent: :nullify
  has_many :collected_pens, through: :micro_clusters

  belongs_to :model_micro_cluster,
             optional: true,
             class_name: "Pens::ModelMicroCluster",
             foreign_key: :pens_model_micro_cluster_id

  paginates_per 100

  scope :ordered,
        lambda {
          order(:brand, :model, :color, :material, :trim_color, :filling_system)
        }

  def self.search(query)
    return self if query.blank?

    query = query.split(/\s+/).join("%")
    joins(micro_clusters: :collected_pens).where(<<~SQL, "%#{query}%").group(
      CONCAT(collected_pens.brand, collected_pens.model, collected_pens.color, collected_pens.material)
      ILIKE ?
    SQL
      "pens_model_variants.id"
    )
  end

  def collected_pens_count
    collected_pens.size
  end
end
