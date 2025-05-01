class InkReview < ApplicationRecord
  belongs_to :macro_cluster
  belongs_to :you_tube_channel, optional: true
  has_many :ink_review_submissions, dependent: :destroy
  has_many :agent_logs, as: :owner, dependent: :destroy

  paginates_per 1

  validates :title, presence: true
  validates :url, presence: true
  validates :image, presence: true
  validate :url_format

  scope :queued, -> { where(approved_at: nil, rejected_at: nil) }
  scope :approved, -> { where.not(approved_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }

  def reject!
    update!(rejected_at: Time.zone.now, approved_at: nil)
  end

  def approve!
    update(approved_at: Time.zone.now, rejected_at: nil)
  end

  def auto_approve!
    update(approved_at: Time.zone.now, rejected_at: nil, auto_approved: true)
  end

  def url=(value)
    set_host!(value)
    write_attribute(:url, value)
  end

  def approved?
    approved_at.present?
  end

  def rejected?
    rejected_at.present?
  end

  def user
    ink_review_submissions.first.user
  end

  private

  def set_host!(value)
    self.host = URI(value).host
  rescue URI::InvalidURIError
  end

  def url_format
    return if url.blank?
    uri = URI(url)
    errors.add(:url, :invalid) if uri.host.blank?
  end
end
