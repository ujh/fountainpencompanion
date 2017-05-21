class Ink < ApplicationRecord
  validates :brand, associated: true
  validates :name, presence: true

  belongs_to :brand
end
