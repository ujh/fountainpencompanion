class InkReview < ApplicationRecord
  belongs_to :macro_cluster
  has_many :ink_review_submissions

  validates :title, presence: true
  validates :url, presence: true
  validates :description, presence: true
  validates :image, presence: true
end
