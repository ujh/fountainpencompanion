class BrandCluster < ApplicationRecord
  has_many :macro_clusters, dependent: :nullify

  def self.public_count
    joins(macro_clusters: { micro_clusters: :collected_inks }).where(
      collected_inks: { private: false }
    ).group("brand_clusters.id").count.count
  end

  def update_name!
    update!(
      name: macro_clusters.group(:brand_name).order(Arel.sql 'count(*) desc').pluck(:brand_name).first
    )
  end

  def synonyms
    macro_clusters.pluck(:brand_name).uniq.sort - [name]
  end
end
