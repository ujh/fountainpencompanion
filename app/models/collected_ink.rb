require "csv"

class CollectedInk < ApplicationRecord
  include Archivable
  include PgSearch::Model

  KINDS = %w[bottle sample cartridge swab]

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, length: { in: 1..100 }
  validates :ink_name, length: { in: 1..100 }
  validates :line_name, length: { in: 1..100, allow_blank: true }

  validate :color_valid

  before_save :simplify
  before_save :add_comment

  belongs_to :user
  has_many :currently_inkeds, dependent: :destroy
  has_many :usage_records, through: :currently_inkeds
  has_one :newest_currently_inked, -> { order("inked_on desc") }, class_name: "CurrentlyInked"
  has_one :ink_embedding, dependent: :destroy, as: :owner

  belongs_to :micro_cluster, optional: true

  pg_search_scope(
    :search,
    against: %i[brand_name line_name ink_name],
    using: {
      tsearch: {
        dictionary: "english",
        tsvector_column: "tsv"
      }
    }
  )

  pg_search_scope(
    :kinda_similar_search,
    against: %i[brand_name line_name ink_name],
    using: {
      tsearch: {
        dictionary: "english",
        tsvector_column: "tsv"
      },
      trigram: {
      }
    }
  )

  Gutentag::ActiveRecord.call self

  delegate :macro_cluster, to: :micro_cluster, allow_nil: true

  def cluster_tags
    return [] unless macro_cluster

    macro_cluster.tags
  end

  def cluster_description
    return "" unless macro_cluster

    macro_cluster.description
  end

  def brand_description
    return "" unless macro_cluster
    return "" unless macro_cluster.brand_cluster

    macro_cluster.brand_cluster.description
  end

  def tags_as_string
    tag_names.join(", ")
  end

  def tags_as_string=(string)
    self.tag_names = string.split(",").map(&:strip)
  end

  def si
    [simplified_brand_name, simplified_line_name, simplified_ink_name]
  end

  def self.without_color
    where(color: "")
  end

  def self.with_color
    where.not(color: "")
  end

  def self.alphabetical
    order("brand_name, line_name, ink_name")
  end

  def self.brand_count
    reorder(:simplified_brand_name).group(:simplified_brand_name).pluck(:simplified_brand_name).size
  end

  def self.unique_inks_per_brand(name)
    # Ignore the simplified_line_name here as it's unlikely that a single brand will have the same
    # ink name in two different lines.
    where(simplified_brand_name: name).group(:simplified_ink_name).count.size
  end

  def self.brands
    reorder(:brand_name).group(:brand_name).pluck(:brand_name)
  end

  def self.bottles
    where(kind: "bottle")
  end

  def self.bottle_count
    bottles.count
  end

  def self.samples
    where(kind: "sample")
  end

  def self.sample_count
    samples.count
  end

  def self.cartridges
    where(kind: "cartridge")
  end

  def self.unswabbed_count
    where(swabbed: false).count
  end

  def self.cartridge_count
    cartridges.count
  end

  def self.to_csv
    CSV.generate(col_sep: ";") do |csv|
      csv << [
        "Brand",
        "Line",
        "Name",
        "Type",
        "Color",
        "Swabbed",
        "Used",
        "Comment",
        "Private Comment",
        "Archived",
        "Archived On",
        "Usage",
        "Tags",
        "Date Added",
        "Maker",
        "Daily Usage",
        "Last Usage"
      ]
      all.each do |ci|
        csv << [
          ci.brand_name,
          ci.line_name,
          ci.ink_name,
          ci.kind,
          ci.color,
          ci.swabbed,
          ci.used,
          ci.comment,
          ci.private_comment,
          ci.archived?,
          ci.archived_on,
          ci.currently_inkeds.length,
          ci.tags_as_string,
          ci.created_at.to_date.to_s,
          ci.maker,
          ci.daily_usage_count,
          ci.last_used_on
        ]
      end
    end
  end

  def color
    read_attribute(:color).presence || cluster_color
  end

  def color=(value)
    super(value.strip) if value.strip != cluster_color
  end

  def name
    n = short_name
    n = "#{n} - #{kind}" if kind.present?
    n = "#{n} (archived)" if archived?
    n
  end

  def short_name
    [brand_name, line_name, ink_name].reject { |f| f.blank? }.join(" ")
  end

  def brand_name=(value)
    super(value.strip)
  end

  def line_name=(value)
    super(value.strip)
  end

  def ink_name=(value)
    super(value.strip)
  end

  def simplified_name
    "#{simplified_brand_name}#{simplified_ink_name}"
  end

  def last_used_on
    newest_currently_inked&.last_used_on || newest_currently_inked&.inked_on
  end

  def usage_count
    currently_inkeds.size
  end

  def daily_usage_count
    usage_records.size
  end

  private

  def add_comment
    return unless changed.any? { |c| %w[brand_name line_name ink_name].include?(c) }
    return unless comment.blank?

    rel =
      user
        .collected_inks
        .where(
          "LOWER(brand_name) = ? AND LOWER(line_name) = ? AND LOWER(ink_name) = ?",
          brand_name.to_s.downcase,
          line_name.to_s.downcase,
          ink_name.to_s.downcase
        )
        .where(kind: kind)
    rel = rel.where("id <> ?", id) if persisted?

    self.comment = [kind.capitalize.presence, "no.", rel.count + 1].compact.join(" ") if rel.exists?
  end

  def simplify
    Simplifier.for_collected_ink(self).run
  end

  def color_valid
    return if read_attribute(:color).blank?
    if read_attribute(:color) !~ /#[0-9a-f]{3}([0-9a-f][3])?/i
      errors.add(:color, "Only valid HTML color codes are supported (e.g #fff or #efefef)")
      return
    end

    Color::RGB.from_html(read_attribute(:color))
  rescue ArgumentError
    errors.add(:color, "Only valid HTML color codes are supported (e.g #fff or #efefef)")
  end
end
