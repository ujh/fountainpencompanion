class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, length: { in: 1..100 }
  validates :ink_name, length: { in: 1..100 }
  validates :line_name, length: { in: 1..100, allow_blank: true }

  validate :unique_constraint

  before_save :simplify

  belongs_to :user

  def self.field_by_term(field, term, user)
    relation = where("#{field} <> ?", '')
    if user
      relation = relation.where("private = ? OR user_id = ?", false, user.id)
    else
      relation = relation.where(private: false)
    end
    relation.where("LOWER(#{field}) LIKE ?", "%#{term.downcase}%").group(field).order(field).pluck(field)
  end

  def self.unique_for_brand(brand_name)
    fields = "brand_name, line_name, ink_name"
    where(brand_name: brand_name).alphabetical.group(fields).select("#{fields}, count(*) as count")
  end

  def self.alphabetical
    order("brand_name, line_name, ink_name")
  end

  def self.brand_count
    reorder(:simplified_brand_name).group(:simplified_brand_name).pluck(:simplified_brand_name).size
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

  def self.cartridge_count
    cartridges.count
  end

  def name
    "#{brand_name} #{line_name} #{ink_name}"
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

  private

  def unique_constraint
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
end
