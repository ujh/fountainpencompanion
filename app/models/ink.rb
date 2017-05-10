class Ink < ApplicationRecord
  validates :manufacturer, associated: true
  validates :name, presence: true

  belongs_to :manufacturer
end
