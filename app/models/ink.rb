class Ink < ApplicationRecord
  validates :name, presence: true

  belongs_to :manufacturer
end
