class CollectedPen < ApplicationRecord
  belongs_to :user

  validates :brand, length: { in: 1..100 }
  validates :model, length: { in: 1..100 }

  def self.search(field, term)
    where("#{field} like ?", "%#{term}%").order(field).pluck(field).uniq
  end

  def name
    "#{brand} #{model}"
  end

  def brand=(value)
    super(value.strip)
  end

  def model=(value)
    super(value.strip)
  end
end
