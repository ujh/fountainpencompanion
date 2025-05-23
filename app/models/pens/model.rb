require "ostruct"

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
    connection.execute("SET hnsw.ef_search = 1000")
    query_embedding = EmbeddingsClient.new.fetch(query)
    model_embeddings =
      PenEmbedding
        .where(owner_type: "Pens::Model")
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .includes(:owner)
        .order(:neighbor_distance)
        .first(200)
        .reject { |e| e.neighbor_distance > 0.6 }
    model_variant_embeddings =
      PenEmbedding
        .where(owner_type: "Pens::ModelVariant")
        .joins(pens_model_variant: { model_micro_cluster: :model })
        .where.not(model: { id: model_embeddings.map(&:owner_id) })
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .includes(owner: { model_micro_cluster: :model })
        .order(:neighbor_distance)
        .first(200)
        .reject { |e| e.neighbor_distance > 0.6 }
    collected_pens_embeddings =
      PenEmbedding
        .where(owner_type: "CollectedPen")
        .joins(
          collected_pen: {
            pens_micro_cluster: {
              model_variant: {
                model_micro_cluster: :model
              }
            }
          }
        )
        .where.not(model: { id: model_embeddings.map(&:owner_id) })
        .where.not(model_variant: { id: model_variant_embeddings.map(&:owner_id) })
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .includes(owner: :pens_micro_cluster)
        .order(:neighbor_distance)
        .first(2000)
        .reject { |e| e.neighbor_distance > 0.6 }
    embeddings = [*model_embeddings, *model_variant_embeddings, *collected_pens_embeddings]
    models = Hash.new { |h, k| h[k] = OpenStruct.new(distance: 1.0, results: []) }
    embeddings.each do |embedding|
      owner = embedding.owner
      model = owner.pen_model
      next unless model

      model_id = model.id
      models[model_id].results << owner
      if models[model_id].distance > embedding.neighbor_distance
        models[model_id].distance = embedding.neighbor_distance
        models[model_id].owner = owner
      end
    end
    models.values.each do |data|
      data.model_variants =
        data
          .results
          .reject { |result| result.is_a?(Pens::Model) }
          .map { |result| result.is_a?(Pens::ModelVariant) ? result : result.pen_variant }
          .uniq
    end
    # Return data sorted by neighbor_distance
    models.values.sort_by(&:distance)
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

  def pen_model
    self
  end
end
