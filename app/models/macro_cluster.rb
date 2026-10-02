require "ostruct"

class MacroCluster < ApplicationRecord
  TRACKED_FIELDS = {
    "description" => "Description",
    "manual_brand_name" => "Brand Name",
    "manual_line_name" => "Line Name",
    "manual_ink_name" => "Ink Name",
    "line_name_is_empty" => "Line Name Empty",
    "ignored_colors" => "Color"
  }.freeze

  InkNameEntry =
    Struct.new(
      :id,
      :brand_name,
      :line_name,
      :ink_name,
      :collected_inks_count,
      keyword_init: true
    ) do
      def slice(*keys)
        to_h.slice(*keys)
      end

      def short_name
        [brand_name, line_name, ink_name].reject(&:blank?).join(" ")
      end
    end

  has_paper_trail
  has_many :description_versions,
           -> do
             conditions = TRACKED_FIELDS.keys.map { "object_changes LIKE ?" }.join(" OR ")
             values = TRACKED_FIELDS.keys.map { |f| "%#{f}%" }
             where(conditions, *values).where(event: "update").order("id desc")
           end,
           class_name: "PaperTrail::Version",
           as: :item

  has_many :micro_clusters, dependent: :nullify
  has_one :popularity, class_name: "MacroClusterPopularity"
  has_many :collected_inks, through: :micro_clusters
  has_many :public_collected_inks, through: :micro_clusters
  has_many :ink_reviews, dependent: :destroy
  has_many :ink_review_submissions, dependent: :destroy
  has_one :ink_embedding, dependent: :destroy, as: :owner
  has_many :agent_logs, as: :owner, dependent: :destroy

  belongs_to :brand_cluster, optional: true

  before_save :recalculate_color, if: :will_save_change_to_ignored_colors?
  after_commit :enqueue_update, if: :saved_change_to_color?
  after_commit :expire_missing_descriptions, if: -> { destroyed? || saved_change_to_description? }

  paginates_per 100
  max_paginates_per 100

  scope :unassigned, -> { where(brand_cluster_id: nil) }
  scope :without_description, -> { where(description: "") }

  # Clusters without any review that is approved or still waiting for
  # approval, i.e. no reviews at all or only rejected ones.
  def self.without_review
    where.not(
      InkReview
        .where(rejected_at: nil)
        .where("ink_reviews.macro_cluster_id = macro_clusters.id")
        .arel
        .exists
    )
  end

  def self.of_user(user)
    joins(:collected_inks).where(collected_inks: { user_id: user.id, archived_on: nil })
  end

  def self.without_review_of_user(user)
    without_review.of_user(user)
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
    return [] if query.blank?

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

  def self.effective_column(field)
    coalesce = "COALESCE(NULLIF(macro_clusters.manual_#{field}, ''), macro_clusters.#{field})"
    if field.to_s == "line_name"
      Arel.sql("CASE WHEN macro_clusters.line_name_is_empty THEN '' ELSE #{coalesce} END")
    else
      Arel.sql(coalesce)
    end
  end

  # Names of the given field for public inks, ranked by AutocompleteRanking.
  # Names that only differ in case are merged and shown with their most popular
  # spelling. Names need more than two public collected inks to show up. If a
  # brand name is given, only inks of that brand are considered.
  #
  # Popularity comes from MacroClusterPopularity, so new inks only show up once
  # that view has been refreshed.
  def self.autocomplete_search(term, field, brand_name = nil)
    effective = effective_column(field)
    variants =
      joins(:popularity)
        .where("#{effective} != ''")
        .group(effective)
        .select(
          "#{effective} AS name",
          "sum(macro_cluster_popularities.public_collected_inks_count) AS popularity",
          "min(macro_clusters.id) AS id"
        )
    simplified_brand_name = Simplifier.brand_name(brand_name.to_s.strip)
    if simplified_brand_name.present?
      variants =
        variants.where(
          id:
            MicroCluster.where(simplified_brand_name: simplified_brand_name).select(
              :macro_cluster_id
            )
        )
    end
    candidates =
      unscoped
        .from(variants, :variants) # The C collation makes sorting for the grouping much faster
        .group(Arel.sql('lower(variants.name) COLLATE "C"'))
        .having("sum(variants.popularity) > 2")
        .select(
          "(array_agg(variants.name ORDER BY variants.popularity DESC))[1] AS name",
          "(array_agg(variants.id ORDER BY variants.popularity DESC))[1] AS id",
          "sum(variants.popularity) AS popularity"
        )
    AutocompleteRanking.new(candidates, term).relation
  end

  def self.autocomplete_line_search(term, brand_name)
    autocomplete_cluster_search(term, :line_name, brand_name)
  end

  def self.autocomplete_ink_search(term, brand_name)
    autocomplete_cluster_search(term, :ink_name, brand_name)
  end

  # One macro cluster per ranked name, in ranking order
  def self.autocomplete_cluster_search(term, field, brand_name)
    ids = unscoped { autocomplete_search(term, field, brand_name).map(&:id) }
    where(id: ids).in_order_of(:id, ids)
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
    ink_reviews.live
  end

  def public_collected_inks_count
    collected_inks.loaded? ? collected_inks.count { |ci| !ci.private } : public_collected_inks.count
  end

  def all_names
    if collected_inks.loaded?
      collected_inks
        .reject(&:private)
        .group_by { |ci| [ci.brand_name, ci.line_name, ci.ink_name] }
        .map do |(brand_name, line_name, ink_name), inks|
          InkNameEntry.new(
            id: inks.first.id,
            brand_name: brand_name,
            line_name: line_name,
            ink_name: ink_name,
            collected_inks_count: inks.size
          )
        end
        .sort_by { |n| -n.collected_inks_count }
    else
      collected_inks
        .where(private: false)
        .group("collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name")
        .select(
          "min(collected_inks.id), collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name, count(*) as collected_inks_count"
        )
        .order("collected_inks_count desc")
    end
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

  def brand_name
    if has_attribute?(:manual_brand_name)
      manual_brand_name.presence || super
    else
      super
    end
  end

  def automatic_brand_name
    read_attribute(:brand_name)
  end

  def line_name
    return "" if has_attribute?(:line_name_is_empty) && line_name_is_empty?

    if has_attribute?(:manual_line_name)
      manual_line_name.presence || super
    else
      super
    end
  end

  def automatic_line_name
    read_attribute(:line_name)
  end

  def ink_name
    if has_attribute?(:manual_ink_name)
      manual_ink_name.presence || super
    else
      super
    end
  end

  def automatic_ink_name
    read_attribute(:ink_name)
  end

  def manual_edits?
    description.present? || manual_brand_name.present? || manual_line_name.present? ||
      manual_ink_name.present? || line_name_is_empty?
  end

  def recalculate_color
    colors =
      collected_inks
        .with_color
        .pluck(:color)
        .reject { |c| ignored_colors.include?(c) }
        .map { |c| Color::RGB.from_html(c) }
    return if colors.blank?

    self.color =
      Color::RGB.from_values(*%i[red green blue].map { |f| color_average_for(colors, f) }).html
  end

  private

  def expire_missing_descriptions
    MissingDescriptions.expire_inks
  end

  def enqueue_update
    UpdateMacroCluster.perform_async(id)
  end

  def color_average_for(colors, field)
    sum = colors.map { |c| c.send(field)**2 }.sum
    size = colors.size.to_f
    Math.sqrt(sum / size).round
  end
end
