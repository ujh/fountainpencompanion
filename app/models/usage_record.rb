class UsageRecord < ApplicationRecord
  belongs_to :currently_inked

  validates :used_on, uniqueness: { scope: :currently_inked_id }
end
