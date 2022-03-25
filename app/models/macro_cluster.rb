class MacroCluster < ApplicationRecord
  has_many :micro_clusters, dependent: :nullify
  has_many :collected_inks, through: :micro_clusters
  has_many :ink_reviews, dependent: :destroy
  belongs_to :brand_cluster, optional: true

  paginates_per 100

  scope :unassigned, -> { where(brand_cluster_id: nil) }

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
    joins(
      :collected_inks
    ).where(
      collected_inks: { user_id: user.id }
    )
  end

  def self.search(query)
    return self if query.blank?

    query = query.split(/\s+/).join('%')
    joins(micro_clusters: :collected_inks).where(<<~SQL,
      CONCAT(collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name)
      ILIKE ?
    SQL
    "%#{query}%").group('macro_clusters.id')
  end

  def self.autocomplete_search(term, field)
    simplified_term = Simplifier.send(field, term.to_s)
    joins(micro_clusters: :collected_inks).where(collected_inks: {private: false}).where(
      "collected_inks.simplified_#{field} LIKE ?", "%#{simplified_term}%"
    ).where.not(
      macro_clusters: { field => ''}
    ).group("macro_clusters.#{field}").order("macro_clusters.#{field}").select(
      "min(macro_clusters.id) as id, macro_clusters.#{field}"
    ).having("count(collected_inks.id) > 2")
  end

  def self.autocomplete_ink_search(term, brand_name)
    simplified_brand_name = Simplifier.brand_name(brand_name)
    query = autocomplete_search(term, :ink_name)
    if simplified_brand_name.present?
      query = query.where("collected_inks.simplified_brand_name LIKE ?", "%#{simplified_brand_name}%")
    end
    query
  end

  def self.public
    joins(micro_clusters: :collected_inks).where(
      collected_inks: { private: false }
    ).group("macro_clusters.id")
  end

  def self.full_text_search(term)
    # These are ordered by rank!
    mc_ids = CollectedInk.search(term).where(private: false).joins(
      micro_cluster: :macro_cluster
    ).pluck('macro_clusters.id').uniq
    MacroCluster.where(id: mc_ids).sort_by do |mc|
      mc_ids.index(mc.id)
    end
  end

  def approved_ink_reviews
    ink_reviews.approved
  end

  def public_collected_inks_count
    collected_inks.where(private: false).count
  end

  def all_names
    collected_inks.where(private: false).group(
      "collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name"
    ).select(
      "min(collected_inks.id), collected_inks.brand_name, collected_inks.line_name, collected_inks.ink_name, count(*) as collected_inks_count"
    ).order("collected_inks_count desc")
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def name
    [brand_name, line_name, ink_name].reject(&:blank?).join(' ')
  end
end
