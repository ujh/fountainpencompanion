class BrandCluster < ApplicationRecord
  has_many :macro_clusters, dependent: :nullify
  has_many :collected_inks, through: :macro_clusters

  def self.public
    joins(macro_clusters: { micro_clusters: :collected_inks }).where(
      collected_inks: { private: false }
    ).group("brand_clusters.id")
  end

  def self.public_count
    public.count.count
  end

  def self.autocomplete_search(term)
    where("name ilike ?", "%#{term}%")
  end

  def public_ink_count
    macro_clusters.public.count.count
  end

  def public_collected_inks_count
    collected_inks.where(private: false).count
  end

  def to_param
    "#{id}-#{name.parameterize}"
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
