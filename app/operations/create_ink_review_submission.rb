class CreateInkReviewSubmission
  def initialize(url:, user:, macro_cluster:, automatic: false, explanation: nil)
    self.url = url
    self.user = user
    self.macro_cluster = macro_cluster
    self.automatic = automatic
    self.explanation = explanation
  end

  def perform
    ProcessInkReviewSubmission.perform_async(submission.id) if submission.persisted?
    submission
  end

  private

  attr_accessor :url, :user, :macro_cluster, :automatic, :explanation

  def submission
    attributes = { url: url, user: user, macro_cluster: macro_cluster }
    @submission ||=
      if automatic
        InkReviewSubmission.create(attributes.merge(extra_data: { explanation: explanation }))
      else
        InkReviewSubmission.find_or_create_by(attributes)
      end
  end
end
