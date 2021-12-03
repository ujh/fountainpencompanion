class ProcessInkReviewSubmission
  include Sidekiq::Worker

  def perform(id)
    self.ink_review_submission = InkReviewSubmission.find(id)
    return unless required_data_present?

    ink_review = InkReview.find_or_create_by!(url: url, macro_cluster: macro_cluster) do |ink_review|
      ink_review.title = title
      ink_review.description = description
      ink_review.image = image
    end
    ink_review_submission.update(ink_review: ink_review)
  end

  private

  attr_accessor :ink_review_submission

  def required_data_present?
    [:title, :url, :image].all? do |data_point|
      send(data_point).present?
    end
  end

  def title
    page_data.title
  end

  def url
    page_data.url.presence || ink_review_submission.url
  end

  def description
    page_data.description
  end

  def image
    page_data.image
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
