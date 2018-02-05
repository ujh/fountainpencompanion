class CollectedPen < ApplicationRecord
  belongs_to :user

  validates :brand, length: { in: 1..100 }
  validates :model, length: { in: 1..100 }

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
