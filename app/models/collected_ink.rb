class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, presence: true
  validates :ink_name, presence: true

  belongs_to :user

  def name
    "#{brand_name} #{line_name} #{ink_name}"
  end

end
