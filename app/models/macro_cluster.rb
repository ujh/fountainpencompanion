class MacroCluster < ApplicationRecord
  has_many :micro_clusters, dependent: :nullify
  has_many :collected_inks, through: :micro_clusters
  belongs_to :brand_cluster, optional: true

  paginates_per 100

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
end
