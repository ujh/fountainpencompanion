class ProcessInkReviewSubmission
  include Sidekiq::Worker

  def perform(id)
    self.ink_review_submission = InkReviewSubmission.find(id)

    ink_review =
      InkReview.find_or_initialize_by(url:, macro_cluster:) do |ink_review|
        ink_review.title = title
        ink_review.description = description
        ink_review.image = image
        ink_review.author = author
      end
    new_record = ink_review.new_record?
    schedule_approval = false
    if ink_review.save
      ink_review.update(rejected_at: nil)
      ink_review_submission.update(ink_review:, unfurling_errors: nil, html: nil)
      if ink_review.auto_approve?
        ink_review.auto_approve!
      elsif ink_review.auto_reject?
        ink_review.auto_reject!
      else
        schedule_approval = true
      end
    else
      ink_review_submission.update(unfurling_errors: ink_review.errors.messages.to_json)
    end
    if you_tube_channel_id
      channel = YouTubeChannel.find_or_create_by(channel_id: you_tube_channel_id)
      ink_review.update!(you_tube_channel: channel, you_tube_short: is_youtube_short)
    end
    RunAgent.perform_async("ReviewApprover", ink_review.id) if new_record && schedule_approval
  rescue URI::InvalidURIError, Faraday::ForbiddenError
    ink_review&.destroy
    ink_review_submission&.destroy
  end

  private

  attr_accessor :ink_review_submission

  delegate :url,
           :title,
           :description,
           :image,
           :author,
           :you_tube_channel_id,
           :is_youtube_short,
           to: :page_data

  def macro_cluster
    ink_review_submission.macro_cluster
  end

  def page_data
    @page_data ||= Unfurler.new(ink_review_submission.url).perform
  end
end
