class Pens::Model < ApplicationRecord
  has_many :model_micro_clusters,
           foreign_key: :pens_model_id,
           class_name: "Pens::ModelMicroCluster",
           dependent: :nullify
  has_many :model_variants, through: :model_micro_clusters
  has_many :micro_clusters, through: :model_variants
  has_many :collected_pens, through: :micro_clusters
  has_one :pen_embedding, dependent: :destroy, as: :owner

  belongs_to :pen_brand, optional: true, class_name: "Pens::Brand", foreign_key: :pens_brand_id

  paginates_per 100

  scope :ordered, -> { order(:brand, :model) }
  scope :unassigned, -> { where(pens_brand_id: nil) }

  def self.search(query)
    return self if query.blank?

    query = query.split(/\s+/).join("%")
    joins(model_micro_clusters: :model_variants).where(<<~SQL, "%#{query}%").group("pens_models.id")
        CONCAT(pens_model_variants.brand, pens_model_variants.model)
        ILIKE ?
      SQL
  end

  def self.embedding_search(query)
    query_embedding = EmbeddingsClient.new.fetch(query)
    PenEmbedding
      .where(owner_type: to_s)
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .includes(:owner)
      .order(:neighbor_distance)
      .first(200)
      .reject { |e| e.neighbor_distance > 0.6 }
  end

  def name
    "#{brand} #{model}"
  end

  def collected_pens_count
    collected_pens.size
  end

  def model_variants_count
    model_variants.size
  end

  def to_param
    "#{id}-#{model.parameterize}"
  end
end
