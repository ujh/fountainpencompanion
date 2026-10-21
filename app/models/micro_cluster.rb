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
    {
      ink_users: collected_inks.distinct.count(:user_id),
      brand_users: brand_users_count,
      brand_catalogue_inks: brand_catalogue_inks_count
    }
  end

  private

  def same_brand_micro_clusters
    MicroCluster.where(simplified_brand_name: simplified_brand_name)
  end

  def brand_users_count
    CollectedInk
      .where(micro_cluster_id: same_brand_micro_clusters.select(:id))
      .distinct
      .count(:user_id)
  end

  def brand_catalogue_inks_count
    return 0 if PLACEHOLDER_BRAND_NAMES.include?(simplified_brand_name)

    same_brand_micro_clusters.without_ignored.distinct.count(:macro_cluster_id)
  end
end
