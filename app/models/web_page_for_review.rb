class WebPageForReview < ApplicationRecord
  belongs_to :review_feed, optional: true
  has_many :agent_logs, as: :owner, dependent: :destroy
end
