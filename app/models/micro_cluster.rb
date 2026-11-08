class MicroCluster < ApplicationRecord
  belongs_to :macro_cluster, optional: true
  has_many :collected_inks
  has_many :public_collected_inks, -> { where(private: false) }, class_name: "CollectedInk"
  has_one :ink_embedding, dependent: :destroy, as: :owner
  has_many :agent_logs, as: :owner, dependent: :destroy

  paginates_per 100

  PLACEHOLDER_BRAND_NAMES = %w[
    cartridge
    custom
    custommix
    diy
    generic
    genericcartridge
    homebrew
    homemade
    idk
    misc
    mix
    mixed
    mystery
    mysteryink
    na
    nobrand
    noname
    none
    other
    personalmix
    placeholder
    random
    sample
    test
    unbranded
    unidentified
    unknown
    unknownbrand
    unkown
    unlabeled
    unlabelled
    various
  ].freeze

  CATALOGUED_BRAND_MIN_LENGTH = 4
  CATALOGUED_BRAND_MIN_INKS = 3

  scope :unassigned, -> { where(macro_cluster_id: nil) }
  scope :without_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }
  scope :for_processing,
        -> do
          # The JOIN is there to remove clusters without inks
          unassigned
            .without_ignored
            .joins(:collected_inks)
            .group("micro_clusters.id")
            .order(updated_at: :asc)
        end

  def simplified_name
    [simplified_brand_name, simplified_line_name, simplified_ink_name].reject { |f| f.blank? }
      .join(" ")
  end

  def all_names
    collected_inks.map(&:short_name).uniq
  end

  def all_names_as_elements
    collected_inks.map { |ink| ink.slice(:brand_name, :line_name, :ink_name) }.uniq
  end

  def colors
    collected_inks.map(&:color).reject(&:blank?).uniq
  end

  def clustering_evidence
    catalogued_brand = catalogued_brand_prefix if brand_catalogue_inks_count(
      [simplified_brand_name]
    ).zero?
    brand_names = [simplified_brand_name, catalogued_brand&.first].compact

    evidence = {
      ink_users: collected_inks.distinct.count(:user_id),
      brand_users: brand_users_count(brand_names),
      brand_catalogue_inks: brand_catalogue_inks_count(brand_names)
    }
    evidence[:catalogued_brand] = catalogued_brand.last if catalogued_brand
    evidence
  end

  private

  def brand_users_count(brand_names)
    CollectedInk
      .where(micro_cluster_id: MicroCluster.where(simplified_brand_name: brand_names).select(:id))
      .distinct
      .count(:user_id)
  end

  def brand_catalogue_inks_count(brand_names)
    return 0 if PLACEHOLDER_BRAND_NAMES.include?(simplified_brand_name)

    MicroCluster
      .where(simplified_brand_name: brand_names)
      .without_ignored
      .distinct
      .count(:macro_cluster_id)
  end

  def catalogued_brand_prefix
    return if PLACEHOLDER_BRAND_NAMES.include?(simplified_brand_name)

    macro_cluster_count = "count(DISTINCT micro_clusters.macro_cluster_id)"
    MicroCluster
      .without_ignored
      .joins(macro_cluster: :brand_cluster)
      .where.not(simplified_brand_name: PLACEHOLDER_BRAND_NAMES)
      .where(
        "length(micro_clusters.simplified_brand_name) BETWEEN ? AND ?",
        CATALOGUED_BRAND_MIN_LENGTH,
        simplified_brand_name.length - 1
      )
      .where(
        "left(?, length(micro_clusters.simplified_brand_name)) = micro_clusters.simplified_brand_name",
        simplified_brand_name
      )
      .group("micro_clusters.simplified_brand_name", "brand_clusters.name")
      .having("#{macro_cluster_count} >= ?", CATALOGUED_BRAND_MIN_INKS)
      .order(
        Arel.sql("length(micro_clusters.simplified_brand_name) DESC, #{macro_cluster_count} DESC")
      )
      .pick("micro_clusters.simplified_brand_name", "brand_clusters.name")
  end
end
