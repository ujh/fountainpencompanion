class CollectedPen < ApplicationRecord
  belongs_to :user

  validates :brand, length: { in: 1..100 }
  validates :model, length: { in: 1..100 }

  def name
    "#{brand} #{model}"
  end
end
