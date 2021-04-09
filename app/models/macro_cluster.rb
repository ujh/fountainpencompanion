class MacroCluster < ApplicationRecord
  has_many :micro_clusters, dependent: :nullify
  has_many :collected_inks, through: :micro_clusters
  belongs_to :brand_cluster, optional: true

  paginates_per 100

  scope :unassigned, -> { where(brand_cluster_id: nil) }

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
