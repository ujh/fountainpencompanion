class Line < ApplicationRecord
  validates :brand, associated: true
  validates :name, presence: true

  belongs_to :brand
  has_many :inks
end
