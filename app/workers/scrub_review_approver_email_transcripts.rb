class ScrubReviewApproverEmailTranscripts
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform
    ScrubReviewApproverEmails.new.perform
  end
end
