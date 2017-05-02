class CollectedInk < ApplicationRecord
  validates :ink, associated: true
  validates :kind, inclusion: { in: %w(bottle sample cartridge), allow_nil: true }

  belongs_to :ink
  belongs_to :user
end
