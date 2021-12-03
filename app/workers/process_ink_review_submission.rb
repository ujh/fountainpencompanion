class ProcessInkReviewSubmission
  include Sidekiq::Worker

  def perform(id)
    self.ink_review_submission = InkReviewSubmission.find(id)
    result = unfurl
    ink_review = InkReview.find_or_create_by!(url: result.url, macro_cluster: ink_review_submission.macro_cluster) do |ink_review|
      ink_review.title = unfurl.title
      ink_review.description = unfurl.description
      ink_review.image = unfurl.image
    end
    ink_review_submission.update(ink_review: ink_review)
  end

  private

  attr_accessor :ink_review_submission

  def unfurl
    Unfurler.new(html).perform
  end

  def html
    Net::HTTP.get(url_to_unfurl)
  end

  def url_to_unfurl
    URI(ink_review_submission.url)
  end
end
