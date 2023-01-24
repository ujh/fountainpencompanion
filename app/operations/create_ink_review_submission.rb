class CreateInkReviewSubmission
  def initialize(url:, user:, macro_cluster:, automatic: false)
    self.url = url
    self.user = user
    self.macro_cluster = macro_cluster
    self.automatic = automatic
  end

  def perform
    if submission.persisted?
      ProcessInkReviewSubmission.perform_async(submission.id)
    end
    submission
  end

  private

  attr_accessor :url
  attr_accessor :user
  attr_accessor :macro_cluster
  attr_accessor :automatic

  def submission
    attributes = { url: url, user: user, macro_cluster: macro_cluster }
    @submission ||=
      if automatic
        InkReviewSubmission.create(attributes)
      else
        InkReviewSubmission.find_or_create_by(attributes)
      end
  end
end
