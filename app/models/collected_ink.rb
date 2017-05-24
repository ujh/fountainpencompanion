class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, length: { in: 1..100 }
  validates :ink_name, length: { in: 1..100 }
  validates :line_name, length: { in: 1..100, allow_blank: true }

  belongs_to :user

  def self.field_by_term(field, term)
    where("LOWER(#{field}) LIKE ?", "#{term.downcase}%").group(field).order(field).pluck(field)
  end

  def name
    "#{brand_name} #{line_name} #{ink_name}"
  end

end
