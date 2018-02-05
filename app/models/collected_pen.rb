class CollectedPen < ApplicationRecord
  belongs_to :user

  def name
    "#{brand} #{model}"
  end
end
