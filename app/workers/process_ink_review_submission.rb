class ProcessInkReviewSubmission
  include Sidekiq::Worker

  def perform(id)
    self.ink_review_submission = InkReviewSubmission.find(id)

    ink_review = InkReview.find_or_initialize_by(url: url, macro_cluster: macro_cluster) do |ink_review|
      ink_review.title = title
      ink_review.description = description
      ink_review.image = image
      ink_review.author = author
    end
    if ink_review.save
      ink_review_submission.update(ink_review: ink_review)
    else
      ink_review_submission.update(unfurling_errors: ink_review.errors.messages.to_json)
    end
  end

  private

  attr_accessor :ink_review_submission

  delegate :title, :description, :image, :author, to: :page_data

  def url
    page_data.url.presence || ink_review_submission.url
  end

  def macro_cluster
    ink_review_submission.macro_cluster
  end

  def page_data
    @page_data ||= Unfurler.new(html).perform
  end

  def html
    connection = Faraday.new do |c|
      c.response :follow_redirects
      c.response :raise_error
    end
    connection.get(url_to_unfurl).body
  end

  def url_to_unfurl
    URI(ink_review_submission.url)
  end
end
