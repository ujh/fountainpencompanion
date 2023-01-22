class ProcessInkReviewSubmission
  include Sidekiq::Worker

  def perform(id)
    self.ink_review_submission = InkReviewSubmission.find(id)

    ink_review =
      InkReview.find_or_initialize_by(
        url: url,
        macro_cluster: macro_cluster
      ) do |ink_review|
        ink_review.title = title
        ink_review.description = description
        ink_review.image = image
        ink_review.author = author
      end
    if ink_review.save
      ink_review.update(rejected_at: nil)
      ink_review_submission.update(
        ink_review: ink_review,
        unfurling_errors: nil,
        html: nil
      )
      ink_review.auto_approve! if (ink_review.ink_review_submissions.size > 1)
    else
      ink_review_submission.update(
        unfurling_errors: ink_review.errors.messages.to_json
      )
    end
    if you_tube_channel_id
      channel =
        YouTubeChannel.find_or_create_by(channel_id: you_tube_channel_id)
      ink_review.update!(you_tube_channel: channel)
    end
  rescue URI::InvalidURIError
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
           to: :page_data

  def macro_cluster
    ink_review_submission.macro_cluster
  end

  def page_data
    @page_data ||= Unfurler.new(ink_review_submission.url).perform
  end
end
