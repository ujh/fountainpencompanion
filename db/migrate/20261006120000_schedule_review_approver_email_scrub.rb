class ScheduleReviewApproverEmailScrub < ActiveRecord::Migration[8.1]
  def up
    ScrubReviewApproverEmailTranscripts.perform_async
  end

  def down
  end
end
