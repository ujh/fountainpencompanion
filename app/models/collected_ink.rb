class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, length: { in: 1..100 }
  validates :ink_name, length: { in: 1..100 }
  validates :line_name, length: { in: 1..100, allow_blank: true }

  belongs_to :user

  def self.field_by_term(field, term)
    where(private: false).
    where("#{field} <> ?", '').
    where("LOWER(#{field}) LIKE ?", "#{term.downcase}%").group(field).order(field).pluck(field)
  end

  def self.unique_count
    group("LOWER(brand_name), LOWER(line_name), LOWER(ink_name)").count.size
  end

  def name
    "#{brand_name} #{line_name} #{ink_name}"
  end

end
