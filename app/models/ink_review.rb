class InkReview < ApplicationRecord
  belongs_to :macro_cluster
  has_many :ink_review_submissions

  validates :title, presence: true
  validates :url, presence: true
  validates :description, presence: true
  validates :image, presence: true

  scope :queued, -> { where(approved_at: nil, rejected_at: nil) }
  scope :approved, -> { where.not(approved_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }
end
