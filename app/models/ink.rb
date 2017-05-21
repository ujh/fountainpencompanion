class Ink < ApplicationRecord
  validates :brand, associated: true
  validates :line, associated: true
  validates :name, presence: true

  belongs_to :brand
  belongs_to :line, optional: true, autosave: true
end
