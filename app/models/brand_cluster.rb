class BrandCluster < ApplicationRecord
  has_paper_trail
  has_many :description_versions,
           -> { where("object_changes like ?", "%description%").order("id desc") },
           class_name: "PaperTrail::Version",
           as: :item

  has_many :macro_clusters, dependent: :nullify
  has_many :collected_inks, through: :macro_clusters

  after_commit :expire_missing_descriptions, if: -> { destroyed? || saved_change_to_description? }

  scope :without_description, -> { where(description: "") }

  def self.without_description_of_user(user)
    without_description_ids = without_description.pluck(:id)
    where(id: without_description_ids).of_user(user)
  end

  def self.of_user(user)
    joins(:collected_inks).where(collected_inks: { user_id: user.id, archived_on: nil })
  end

  # Brands with at least one public collected ink. MacroClusterPopularity
  # only has rows for clusters with public collected inks and is refreshed
  # hourly, so this avoids joining all collected inks.
  def self.public
    where(id: MacroCluster.joins(:popularity).select(:brand_cluster_id))
  end

  def self.public_count
    public.count
  end

  # Brands ranked by AutocompleteRanking, using the number of public
  # collected inks (from MacroClusterPopularity) as popularity
  def self.autocomplete_search(term)
    popularities =
      MacroClusterPopularity
        .joins(:macro_cluster)
        .group("macro_clusters.brand_cluster_id")
        .select(
          "macro_clusters.brand_cluster_id",
          "sum(macro_cluster_popularities.public_collected_inks_count) AS popularity"
        )
    candidates =
      joins(
        "LEFT JOIN (#{popularities.to_sql}) popularities " \
          "ON popularities.brand_cluster_id = brand_clusters.id"
      ).select("brand_clusters.*", "COALESCE(popularities.popularity, 0) AS popularity")
    AutocompleteRanking.new(candidates, term).relation
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
    grouped =
      macro_clusters
        .pluck(:brand_name)
        .map { |n| n.gsub("’", "'").gsub(/\(.*\)/, "").strip }
        .group_by(&:itself)
        .transform_values(&:count)
    update!(name: grouped.max_by(&:last).first)
  end

  def synonyms
    macro_clusters.pluck(:brand_name).uniq.sort - [name]
  end

  private

  def expire_missing_descriptions
    MissingDescriptions.expire_brands
  end
end
