class UsageRecord < ApplicationRecord
  belongs_to :currently_inked

  paginates_per 100

  validates :used_on, uniqueness: { scope: :currently_inked_id }, presence: true

  delegate :pen_name, :ink_name, to: :currently_inked
end
