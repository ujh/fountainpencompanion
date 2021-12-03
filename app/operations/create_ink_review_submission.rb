class CreateInkReviewSubmission
  def initialize(url:, user:, macro_cluster:)
    self.url = url
    self.user = user
    self.macro_cluster = macro_cluster
  end

  def perform
    submission = InkReviewSubmission.create(url: url, user: user, macro_cluster: macro_cluster)
    if submission.persisted?
      ProcessInkReviewSubmission.perform_async(submission.id)
    end
    submission
  end

  private

  attr_accessor :url
  attr_accessor :user
  attr_accessor :macro_cluster
end
