class WebPageForReview < ApplicationRecord
  has_many :agent_logs, as: :owner, dependent: :destroy
end
