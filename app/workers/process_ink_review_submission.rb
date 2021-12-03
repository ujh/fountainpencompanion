require 'open-uri'

class ProcessInkReviewSubmission
  include Sidekiq::Worker

  def perform(id)
    self.ink_review_submission = InkReviewSubmission.find(id)
    result = unfurl
    ink_review = InkReview.find_or_create_by(url: result.url) do |ink_review|
      ink_review.title = unfurl.title
      ink_review.description = unfurl.description
      ink_review.image = unfurl.image
      ink_review.macro_cluster = ink_review_submission.macro_cluster
    end
    ink_review_submission.update(ink_review: ink_review)
  end

  private

  attr_accessor :ink_review_submission

  def unfurl
    Unfurler.new(URI.open(url_to_unfurl)).perform
  end

  def url_to_unfurl
    ink_review_submission.url
  end
end
