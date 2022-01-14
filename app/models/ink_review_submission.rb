class InkReviewSubmission < ApplicationRecord
  belongs_to :macro_cluster
  belongs_to :user
  belongs_to :ink_review, optional: true

  validates :url, presence: true
  validates :url, uniqueness: { scope: [:user_id, :macro_cluster_id], case_sensitive: false }

  scope :unassigned, -> { where(ink_review: nil) }
end
