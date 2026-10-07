class CreateInkReviewSubmission
  DAILY_LIMIT = 150

  def initialize(url:, user:, macro_cluster:, automatic: false, explanation: nil)
    self.url = url
    self.user = user
    self.macro_cluster = macro_cluster
    self.automatic = automatic
    self.explanation = explanation
  end

  def perform
    ProcessInkReviewSubmission.perform_async(submission.id) if needs_processing?
    submission
  end

  private

  attr_accessor :url, :user, :macro_cluster, :automatic, :explanation

  def needs_processing?
    submission.persisted? && (submission.previously_new_record? || submission.ink_review_id.nil?)
  end

  def submission
    @submission ||= automatic ? create_automatic_submission : find_or_create_human_submission
  end

  def attributes
    { url: url, user: user, macro_cluster: macro_cluster }
  end

  def create_automatic_submission
    InkReviewSubmission.create(attributes.merge(extra_data: { explanation: explanation }))
  end

  def find_or_create_human_submission
    existing = InkReviewSubmission.find_by(attributes)
    return existing if existing
    return limit_reached_submission if daily_limit_reached?

    InkReviewSubmission.create(attributes)
  end

  def daily_limit_reached?
    return false unless user

    user.ink_review_submissions.where(created_at: 24.hours.ago..).count >= DAILY_LIMIT
  end

  def limit_reached_submission
    InkReviewSubmission
      .new(attributes)
      .tap do |submission|
        submission.errors.add(
          :base,
          "You've reached the daily limit of review submissions, please try again tomorrow"
        )
      end
  end
end
