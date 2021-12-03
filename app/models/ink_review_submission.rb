class InkReviewSubmission < ApplicationRecord
  belongs_to :macro_cluster
  belongs_to :user
  belongs_to :ink_review, optional: true

  validates :url, presence: true

  scope :unassigned, -> { where(ink_review: nil) }
end
