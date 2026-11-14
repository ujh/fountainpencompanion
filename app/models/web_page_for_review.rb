class WebPageForReview < ApplicationRecord
  STATES = %w[pending processed skipped filtered].freeze

  belongs_to :review_feed, optional: true
  has_many :agent_logs, as: :owner, dependent: :destroy
end
