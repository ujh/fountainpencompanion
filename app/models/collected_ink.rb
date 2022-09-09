require 'csv'

class CollectedInk < ApplicationRecord

  include Archivable
  include PgSearch::Model

  KINDS = %w(bottle sample cartridge swab)

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, length: { in: 1..100 }
  validates :ink_name, length: { in: 1..100 }
  validates :line_name, length: { in: 1..100, allow_blank: true }

  validate :color_valid
  validate :unique_constraint

  before_save :simplify

  belongs_to :user
  has_many :currently_inkeds
  has_many :usage_records, through: :currently_inkeds
  belongs_to :micro_cluster, optional: true

  pg_search_scope(
    :search,
    against: %i(
      brand_name
      line_name
      ink_name
    ),
    using: {
      tsearch: {
        dictionary: "english",
        tsvector_column: "tsv",
      },
      trigram: {},
    }
  )

  Gutentag::ActiveRecord.call self

  def tags_as_string
    tag_names.join(", ")
  end

  def tags_as_string=(string)
    self.tag_names = string.split(',').map(&:strip)
  end

  def si
    [simplified_brand_name, simplified_line_name, simplified_ink_name]
  end

  def self.without_color
    where(color: '')
  end

  def self.with_color
    where.not(color: '')
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
      csv << ["Brand", "Line", "Name", "Type", "Color", "Swabbed", "Used", "Comment", "Private Comment", "Archived", "Usage", "Tags"]
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
          ci.currently_inkeds.length,
          ci.tags_as_string
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
    [brand_name, line_name, ink_name].reject {|f| f.blank? }.join(' ')
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

  def deletable?
    currently_inked_count == 0
  end

  def simplified_name
    "#{simplified_brand_name}#{simplified_ink_name}"
  end

  private

  def unique_constraint
    return unless changed.any? {|c| ['brand_name', 'line_name', 'ink_name'].include?(c)}
    rel = self.class.where(
      "LOWER(brand_name) = ? AND LOWER(line_name) = ? AND LOWER(ink_name) = ?",
      brand_name.to_s.downcase,
      line_name.to_s.downcase,
      ink_name.to_s.downcase
    ).where(user_id: user_id).where(kind: kind)
    rel = rel.where("id <> ?", id) if persisted?
    errors.add(:ink_name, "Duplicate!") if rel.exists?
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
