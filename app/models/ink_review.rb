class InkReview < ApplicationRecord
  CHECK_INTERVAL = 2.months
  RETRY_INTERVAL = 24.hours
  MAX_FAILED_CHECKS = 5

  belongs_to :macro_cluster
  belongs_to :you_tube_channel, optional: true
  has_many :ink_review_submissions, dependent: :destroy
  has_many :ink_review_checks, dependent: :destroy
  has_many :agent_logs, as: :owner, dependent: :destroy

  paginates_per 1

  validates :title, presence: true
  validates :url, presence: true
  validates :image, presence: true
  validate :url_format

  scope :queued, -> { where(approved_at: nil, rejected_at: nil) }
  scope :approved, -> { where.not(approved_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }
  scope :processed, -> { where.not(approved_at: nil).or(where.not(rejected_at: nil)) }
  scope :manually_processed, -> { processed.where(agent_approved: false) }
  scope :agent_processed, -> { processed.where(agent_approved: true) }
  scope :live, -> { approved.where(check_count: 0) }
  scope :due_for_check, -> { approved.where("next_check_at <= ?", Time.zone.now) }
  scope :link_broken, -> { where("check_count > 0 AND check_count < ?", MAX_FAILED_CHECKS) }
  scope :link_removed, -> { where("check_count >= ?", MAX_FAILED_CHECKS) }

  def reject!
    update!(
      rejected_at: Time.zone.now,
      approved_at: nil,
      agent_approved: false,
      auto_approved: false,
      next_check_at: nil,
      check_count: 0
    )
  end

  def approve!
    update(
      approved_at: Time.zone.now,
      rejected_at: nil,
      agent_approved: false,
      auto_approved: false,
      next_check_at: CHECK_INTERVAL.from_now,
      check_count: 0
    )
  end

  def auto_approve!
    update(
      approved_at: Time.zone.now,
      rejected_at: nil,
      auto_approved: true,
      next_check_at: CHECK_INTERVAL.from_now,
      check_count: 0
    )
  end

  def auto_reject!
    update(
      rejected_at: Time.zone.now,
      approved_at: nil,
      auto_approved: true,
      next_check_at: nil,
      check_count: 0
    )
  end

  def agent_approve!
    update(
      approved_at: Time.zone.now,
      rejected_at: nil,
      agent_approved: true,
      next_check_at: CHECK_INTERVAL.from_now,
      check_count: 0
    )
  end

  def agent_reject!
    update(
      rejected_at: Time.zone.now,
      approved_at: nil,
      agent_approved: true,
      next_check_at: nil,
      check_count: 0
    )
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

  def auto_approve?
    user.auto_approve_ink_reviews? || ink_review_submissions.count > 1
  end

  def auto_reject?
    return unless you_tube_short?
    return unless user.admin?

    macro_cluster.ink_reviews.live.exists?
  end

  # Fetches YouTube comments and captions and persists them on the review.
  # Lazy / fetch-once: re-runs are skipped once youtube_metadata_fetched_at is
  # set. Tags are not (re-)fetched here — they're populated synchronously in
  # ProcessInkReviewSubmission from the snippet response.
  def ensure_youtube_metadata!
    return if you_tube_channel_id.blank?
    return if youtube_metadata_fetched_at.present?

    vid = video_id
    return if vid.blank?

    with_lock do
      return if youtube_metadata_fetched_at.present?

      update!(
        youtube_comments: Unfurler::Youtube::Comments.new(vid).fetch,
        youtube_captions: Unfurler::Youtube::Captions.new(vid).fetch,
        youtube_metadata_fetched_at: Time.current
      )
    end
  end

  def video_id
    Youtube::VideoIdParser.parse(url)
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
