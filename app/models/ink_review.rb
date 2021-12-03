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

  def reject!
    update!(rejected_at: Time.zone.now, approved_at: nil)
  end

  def approve!
    update(approved_at: Time.zone.now, rejected_at: nil)
  end

  def approved?
    approved_at.present?
  end

  def rejected?
    rejected_at.present?
  end
end
