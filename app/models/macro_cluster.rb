class MacroCluster < ApplicationRecord
  has_many :micro_clusters, dependent: :nullify
  has_many :collected_inks, through: :micro_clusters

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
end
