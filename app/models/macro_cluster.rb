require "ostruct"

class MacroCluster < ApplicationRecord
  has_paper_trail
  has_many :description_versions,
           -> { where("object_changes like ?", "%description%").order("id desc") },
           class_name: "PaperTrail::Version",
           as: :item

  has_many :micro_clusters, dependent: :nullify
  has_many :collected_inks, through: :micro_clusters
  has_many :public_collected_inks, through: :micro_clusters
  has_many :ink_reviews, dependent: :destroy
  has_many :approved_ink_reviews, -> { approved }, class_name: "InkReview"
  has_many :ink_review_submissions, dependent: :destroy
  has_one :ink_embedding, dependent: :destroy, as: :owner
  has_many :agent_logs, as: :owner, dependent: :destroy

  belongs_to :brand_cluster, optional: true

  paginates_per 100

  scope :unassigned, -> { where(brand_cluster_id: nil) }
  scope :without_description, -> { where(description: "") }

  def self.without_review
    MacroCluster.find_by_sql(<<~SQL)
      WITH no_reviews AS (
        SELECT macro_clusters.*
        FROM macro_clusters
        LEFT OUTER JOIN ink_reviews ON macro_clusters.id = ink_reviews.macro_cluster_id
        WHERE ink_reviews.id IS NULL
      ),
      only_rejected_reviews AS (
        SELECT macro_clusters.* FROM macro_clusters
        JOIN ink_reviews ON macro_clusters.id = ink_reviews.macro_cluster_id
        GROUP BY macro_clusters.id
        HAVING EVERY(ink_reviews.rejected_at IS NOT NULL)
      )
      SELECT * FROM no_reviews
      UNION
      SELECT * FROM only_rejected_reviews
    SQL
  end

  def self.of_user(user)
    joins(:collected_inks).where(collected_inks: { user_id: user.id, archived_on: nil })
  end

  def self.without_review_of_user(user)
    unreviewed_ids = without_review.pluck(:id)
    where(id: unreviewed_ids).of_user(user)
  end

  def self.without_description_of_user(user)
    without_description_ids = without_description.pluck(:id)
    where(id: without_description_ids).of_user(user)
  end

  def self.search(query)
    return self if query.blank?

    query = query.split(/\s+/).join("%")
    joins(micro_clusters: :collected_inks).where(<<~SQL, "%#{query}%").group("macro_clusters.id")
      CONCAT(collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name)
      ILIKE ?
    SQL
  end

  # NOTE: This is not performant, and should only be used in the background
  def self.embedding_search(query)
    connection.execute("SET hnsw.ef_search = 200")
    query_embedding = EmbeddingsClient.new.fetch(query)
    # This needs to do multiple queries as it is not possible to do the filtering
    # by distance in the database. So we need to get the first N results and do
    # the filtering afterwards. With so many collected inks this in turn means
    # that we might miss some of the closest results, e.g. from the clusters.
    #
    # What we do here is then first search the macro clusters, exclude them from
    # the search for micro clusters and then exclude both in the search for the
    # collected inks. Then we can apply different limits for the different
    # types and hopefully get better results.
    macro_cluster_embeddings =
      InkEmbedding
        .where(owner_type: "MacroCluster")
        .includes(:owner)
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .order(:neighbor_distance)
        .first(200)
        .reject { |e| e.neighbor_distance > 0.6 }
    micro_cluster_embeddings =
      InkEmbedding
        .where(owner_type: "MicroCluster")
        .joins(micro_cluster: :macro_cluster)
        .where.not(macro_clusters: { id: macro_cluster_embeddings.map(&:owner_id) })
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .includes(owner: :macro_cluster)
        .order(:neighbor_distance)
        .first(200)
        .reject { |e| e.neighbor_distance > 0.6 }
    collected_ink_embeddings =
      InkEmbedding
        .where(owner_type: "CollectedInk")
        .joins(collected_ink: { micro_cluster: :macro_cluster })
        .where.not(macro_clusters: { id: macro_cluster_embeddings.map(&:owner_id) })
        .where.not(micro_clusters: { id: micro_cluster_embeddings.map(&:owner_id) })
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .includes(owner: { micro_cluster: :macro_cluster })
        .order(:neighbor_distance)
        .first(2000)
        .reject { |e| e.neighbor_distance > 0.6 }
    embeddings = [*macro_cluster_embeddings, *micro_cluster_embeddings, *collected_ink_embeddings]
    clusters = Hash.new { |h, k| h[k] = OpenStruct.new(distance: 1.0, cluster: nil) }
    embeddings.each do |embedding|
      owner = embedding.owner
      next unless owner

      cluster = owner.macro_cluster
      next unless cluster

      cluster_id = cluster.id
      next unless clusters[cluster_id].distance > embedding.neighbor_distance

      clusters[cluster_id].distance = embedding.neighbor_distance
      clusters[cluster_id].cluster = cluster
    end
    # Return data sorted by neighbor_distance
    clusters.values.sort_by(&:distance)
  end

  def self.autocomplete_search(term, field)
    simplified_term = Simplifier.send(field, term.to_s)
    joins(micro_clusters: :collected_inks)
      .where(collected_inks: { private: false })
      .where("collected_inks.simplified_#{field} LIKE ?", "%#{simplified_term}%")
      .where.not(macro_clusters: { field => "" })
      .group("macro_clusters.#{field}")
      .order("macro_clusters.#{field}")
      .select("min(macro_clusters.id) as id, macro_clusters.#{field}")
      .having("count(collected_inks.id) > 2")
  end

  def self.autocomplete_line_search(term, brand_name)
    simplified_brand_name = Simplifier.brand_name(brand_name.to_s)
    query = autocomplete_search(term, :line_name)
    if simplified_brand_name.present?
      query =
        query.where("collected_inks.simplified_brand_name LIKE ?", "%#{simplified_brand_name}%")
    end
    query
  end

  def self.autocomplete_ink_search(term, brand_name)
    simplified_brand_name = Simplifier.brand_name(brand_name.to_s)
    query = autocomplete_search(term, :ink_name)
    if simplified_brand_name.present?
      query =
        query.where("collected_inks.simplified_brand_name LIKE ?", "%#{simplified_brand_name}%")
    end
    query
  end

  def self.public
    joins(micro_clusters: :collected_inks).where(collected_inks: { private: false }).group(
      "macro_clusters.id"
    )
  end

  def self.full_text_search(term, fuzzy: false)
    search_method = fuzzy ? :kinda_similar_search : :search
    # These are ordered by rank!
    mc_ids =
      CollectedInk
        .send(search_method, term)
        .where(private: false)
        .joins(micro_cluster: :macro_cluster)
        .pluck("macro_clusters.id")
        .uniq
    MacroCluster.where(id: mc_ids).sort_by { |mc| mc_ids.index(mc.id) }
  end

  def macro_cluster
    self
  end

  def approved_ink_reviews
    ink_reviews.approved
  end

  def public_collected_inks_count
    public_collected_inks.count
  end

  def all_names
    collected_inks
      .where(private: false)
      .group("collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name")
      .select(
        "min(collected_inks.id), collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name, count(*) as collected_inks_count"
      )
      .order("collected_inks_count desc")
  end

  def synonyms
    all_names.map(&:short_name) - [name]
  end

  def all_names_as_elements
    all_names.map { |ink| ink.slice(:brand_name, :line_name, :ink_name) }
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def name
    [brand_name, line_name, ink_name].reject(&:blank?).join(" ")
  end
end
