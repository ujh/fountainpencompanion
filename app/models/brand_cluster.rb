class BrandCluster < ApplicationRecord
  has_many :macro_clusters, dependent: :nullify

  def self.public_count
    joins(macro_clusters: { micro_clusters: :collected_inks }).where(
      collected_inks: { private: false }
    ).group("brand_clusters.id").count.count
  end

  def self.autocomplete_search(term)
    simplified_term = Simplifier.brand_name(term.to_s)
    joins(macro_clusters: {micro_clusters: :collected_inks}).where(
      collected_inks: {private: false}
    ).where(
      "collected_inks.simplified_brand_name LIKE ?", "%#{simplified_term}%"
    ).group("brand_clusters.name").order("brand_clusters.name").select(
      "min(brand_clusters.id) as id, brand_clusters.name"
    ).having("count(collected_inks.id) > 2")
  end

  def update_name!
    grouped = macro_clusters.pluck(:brand_name).map do |n|
      n.gsub('’',"'").gsub(/\(.*\)/, '').strip
    end.group_by(&:itself).transform_values(&:count)
    update!(
      name: grouped.max_by(&:last).first
    )
  end

  def synonyms
    macro_clusters.pluck(:brand_name).uniq.sort - [name]
  end
end
