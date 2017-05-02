class CollectedInk < ApplicationRecord
  validates :ink, associated: true
  validates :kind, inclusion: { in: %w(bottle sample cartridge), allow_nil: true }

  belongs_to :ink
  belongs_to :user

  def manufacturer_name
    manufacturer.name
  end

  def name
    ink.name
  end

  private

  def manufacturer
    ink.manufacturer
  end
end
